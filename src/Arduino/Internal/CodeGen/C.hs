-- Copyright (c) 2014 Contributors as noted in the AUTHORS file
--
-- This file is part of frp-arduino.
--
-- frp-arduino is free software: you can redistribute it and/or modify
-- it under the terms of the GNU General Public License as published by
-- the Free Software Foundation, either version 3 of the License, or
-- (at your option) any later version.
--
-- frp-arduino is distributed in the hope that it will be useful,
-- but WITHOUT ANY WARRANTY; without even the implied warranty of
-- MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
-- GNU General Public License for more details.
--
-- You should have received a copy of the GNU General Public License
-- along with frp-arduino.  If not, see <http://www.gnu.org/licenses/>.

module Arduino.Internal.CodeGen.C
    ( streamsToC
    ) where

import Arduino.Internal.CodeGen.BlockDoc
import Arduino.Internal.DAG
import Control.Monad
import Data.List (intersperse)
import qualified Data.Map as M

data ResultValue = Value String CType Storage (Maybe String)
                 | FilterVariable String CType String
                 | ToFlatVariable String CType
                 | Void

data Storage = Variable
             | Literal

data CType = CBit
           | CByte
           | CWord
           | CVoid
           | CList CType
           | CTuple [CType]
           deriving (Eq, Show)

listSizeCType :: CType
listSizeCType = CByte

argIndexCType :: CType
argIndexCType = CByte

streamsToC :: Streams -> String
streamsToC = runGen . genStreamsCFile

genStreamsCFile :: Streams -> Gen ()
genStreamsCFile streams = do
    header "// This file is automatically generated."
    header ""
    header "#include <avr/io.h>"
    header "#include <util/delay_basic.h>"
    header "#include <stdbool.h>"
    header ""
    genCTypes
    genStreamCFunctions (sortStreams streams) M.empty
    line ""
    block "int main(void) {" $ do
        mapM genInit (streamsInTree streams)
        block "while (1) {" $ do
            mapM genInputCall (filter (null . inputs) (streamsInTree streams))
        line "}"
        line "return 0;"
    line "}"

genCTypes :: Gen ()
genCTypes = do
    header $ "struct list {"
    header $ "    " ++ cTypeStr listSizeCType ++ " size;"
    header $ "    void* values;"
    header $ "};"
    forM_ [2, 6] $ \n -> do
        header $ ""
        header $ "struct tuple" ++ show n ++ " {"
        forM_ [0..n-1] $ \value -> do
            header $ "    void* value" ++ show value ++ ";"
        header $ "};"

genStreamCFunctions :: [Stream] -> M.Map String CType -> Gen ()
genStreamCFunctions streams streamTypeMap = case streams of
    []                   -> return ()
    (stream:restStreams) -> do
        cType <- genStreamCFunction streamTypeMap stream
        let updateStreamTypeMap = M.insert (name stream) cType streamTypeMap
        genStreamCFunctions restStreams updateStreamTypeMap

genStreamCFunction :: M.Map String CType -> Stream -> Gen CType
genStreamCFunction streamTypes stream = do
    let inputTypes = map (streamTypes M.!) (inputs stream)
    let inputMap = M.fromList $ zip [0..] inputTypes
    let args = streamArguments streamTypes stream
    let declaration = ("static void " ++ name stream ++
                       "(" ++ streamToArgumentList streamTypes stream ++ ")")
    cFunction declaration $ do
        genStreamInputParsing args
        outputNames <- genStreamBody inputMap (body stream)
        genStreamOutputCalling outputNames stream
        return $ resultType outputNames

streamArguments :: M.Map String CType -> Stream -> [(String, String, Int)]
streamArguments streamTypes =
    map (\(input, cType) -> ("input_" ++ show input, cTypeStr cType, input)) .
    zip [0..] .
    map (streamTypes M.!) .
    inputs

streamToArgumentList :: M.Map String CType -> Stream -> String
streamToArgumentList streamTypes stream
    | length (inputs stream) < 1 = ""
    | otherwise                  = cTypeStr argIndexCType ++ " arg, void* value"

genStreamInputParsing :: [(String, String, Int)] -> Gen ()
genStreamInputParsing args = do
    when ((length args) > 0) $ do
        forM_ args $ \(name, cType, _) -> do
            line $ "static " ++ cType ++ " " ++ name ++ ";"
        block "switch (arg) {" $ do
            forM_ args $ \(name, cType, n) -> do
                block ("case " ++ show n ++ ":") $ do
                    line $ name ++ " = *((" ++ cType ++ "*)value);"
                    line $ "break;"
        line $ "}"

genStreamBody :: M.Map Int CType -> Body -> Gen [ResultValue]
genStreamBody inputMap body = case body of
    (Map expression) -> do
        fmap (:[]) $ genExpression inputMap False expression
    (MapMany values) -> do
        mapM (genExpression inputMap False) values
    (Fold expression startValue) -> do
        (Value cStartValue cTypeStartValue _ Nothing) <-
            genExpression inputMap True startValue
        header $ concat [ "static "
                        , cTypeStr cTypeStartValue
                        , " input_1 = "
                        , cStartValue
                        , ";"
                        ]
        (Value cExpression cType _ Nothing) <-
            let inputMapWithStartState = M.insert 1 cTypeStartValue inputMap
            in genExpression inputMapWithStartState False expression
        genCopy "input_1" cExpression cTypeStartValue
        fmap (:[]) $ variable "input_1" cType
    (Filter condition) -> do
        (Value cCondition CBit _ Nothing) <-
            genExpression inputMap False condition
        (Value cValue cType _ Nothing) <-
            genExpression inputMap False (Input 0)
        return [FilterVariable cValue cType cCondition]
    (DelayMicroseconds delay expression) -> do
        (Value cDelay CWord _ Nothing) <-
            genExpression inputMap False delay
        (Value cExpression cType storage Nothing) <-
            genExpression inputMap False expression
        return [Value cExpression cType storage (Just cDelay)]
    (Flatten expression) -> do
        (Value cExpression (CList cTypeItem) _ Nothing) <-
            genExpression inputMap False expression
        return [ToFlatVariable cExpression cTypeItem]
    (Driver _ bodyLLI) -> do
        fmap (:[]) $ genLLI bodyLLI

genExpression :: M.Map Int CType -> Bool -> Expression -> Gen ResultValue
genExpression inputMap static expression = case expression of
    (Not operand) -> do
        (Value cOperand CBit _ Nothing) <-
            genExpression inputMap static operand
        literal CBit $ "!(" ++ cOperand ++ ")"
    (Even operand) -> do
        (Value cOperand CWord _ Nothing) <-
            genExpression inputMap static operand
        literal CBit $ "(" ++ cOperand ++ ") % 2 == 0"
    (Greater left right) -> do
        (Value cLeft  CWord _ Nothing) <- genExpression inputMap static left
        (Value cRight CWord _ Nothing) <- genExpression inputMap static right
        literal CBit $ "(" ++ cLeft ++ " > " ++ cRight ++ ")"
    (Add left right) -> do
        (Value cLeft  CWord _ Nothing) <- genExpression inputMap static left
        (Value cRight CWord _ Nothing) <- genExpression inputMap static right
        literal CWord $ "(" ++ cLeft ++ " + " ++ cRight ++ ")"
    (Sub left right) -> do
        (Value cLeft  CWord _ Nothing) <- genExpression inputMap static left
        (Value cRight CWord _ Nothing) <- genExpression inputMap static right
        literal CWord $ "(" ++ cLeft ++ " - " ++ cRight ++ ")"
    (Input value) -> do
        variable ("input_" ++ show value) (inputMap M.! value)
    (ByteConstant value) -> do
        literal CByte $ show value
    (BoolToBit operand) -> do
        genExpression inputMap static operand
    (IsHigh operand) -> do
        genExpression inputMap static operand
    (BitConstant value) -> do
        case value of
            High -> literal CBit "true"
            Low  -> literal CBit "false"
    (ListConstant values) -> do
        exprs <- mapM (genExpression inputMap static) values
        temp <- genCVariable "struct list"
        v <- label
        header $ cTypeStr (resultType exprs) ++ " " ++ v ++ "[" ++ show (length exprs) ++ "];"
        forM (zip [0..] exprs) $ \(i, (Value x _ _ Nothing)) -> do
            line $ v ++ "[" ++ show i ++ "] = " ++ x ++ ";"
        line $ temp ++ ".size = " ++ show (length exprs) ++ ";"
        line $ temp ++ ".values = (void*)" ++ v ++ ";"
        variable temp (CList $ resultType exprs)
    (TupleValue n tuple) -> do
        (Value name (CTuple cTypes) _ Nothing) <- genExpression inputMap static tuple
        let cType = cTypes !! n
        let res = concat [ "*"
                         , "((" ++ cTypeStr cType ++ "*)"
                         , name
                         , ".value"
                         , show n
                         , ")"
                         ]
        variable res cType
    (TupleConstant values) -> do
        if static
            then do
                valueVariables <- forM values $ \value -> do
                    (Value cExpression cType _ Nothing) <- genExpression inputMap static value
                    name <- genStaticCVariable (cTypeStr cType) cExpression
                    return $ Value name cType Variable Nothing
                let res = concat (
                                 [ "{ "
                                 ]
                                 ++
                                 intersperse ", " (map (\(n, (Value name _ _ _)) -> ".value" ++ show n ++ " = (void*)&" ++ name) (zip [0..] valueVariables))
                                 ++
                                 [ " }"
                                 ]
                                 )
                variable res (CTuple $ map extract valueVariables)
            else do
                valueVariables <- forM values $ \value -> do
                    (Value cExpression cType _ _) <- genExpression inputMap static value
                    wrap cExpression cType
                name <- genCVariable ("struct tuple" ++ show (length valueVariables))
                forM_ (zip [0..] valueVariables) $ \(n, (Value x _ _ _)) ->
                    line $ name ++ ".value" ++ show n ++ " = (void*)&" ++ x ++ ";"
                variable name (CTuple $ map extract valueVariables)
    (NumberToByteArray operand) -> do
        (Value r CWord _ _) <- genExpression inputMap static operand
        charBuf <- label
        header $ cTypeStr CByte ++ " " ++ charBuf ++ "[20];"
        line $ "snprintf(" ++ charBuf ++ ", 20, \"%d\", " ++ r ++ ");"
        temp <- genCVariable "struct list"
        line $ temp ++ ".size = strlen(" ++ charBuf ++ ");"
        line $ temp ++ ".values = " ++ charBuf ++ ";"
        variable temp (CList CByte)
    (WordConstant value) -> do
        literal CWord $ show value
    (If conditionExpression trueExpression falseExpression) -> do
        (Value cCondition CBit _ _) <-
            genExpression inputMap static conditionExpression
        (Value cTrue cType _ _) <-
            genExpression inputMap static trueExpression
        (Value cFalse cType _ _) <-
            genExpression inputMap static falseExpression
        temp <- genCVariable (cTypeStr cType)
        block ("if (" ++ cCondition ++ ") {") $ do
            line $ temp ++ " = " ++ cTrue ++ ";"
        block "} else {" $ do
            line $ temp ++ " = " ++ cFalse ++ ";"
        line $ "}"
        variable temp cType

genCopy :: String -> String -> CType -> Gen ()
genCopy destination source cType = case cType of
    CTuple items -> forM_ (zip [0..] items) $ \(n, itemType) -> do
        let drill x = concat [ "*"
                             , "("
                             , "(" ++ cTypeStr itemType ++ "*)"
                             , x
                             , ".value"
                             , show n
                             , ")"
                             ]
        genCopy (drill destination) (drill source) itemType
    _ -> line $ destination ++ " = " ++ source ++ ";"

genLLI :: LLI -> Gen ResultValue
genLLI lli = case lli of
    (WriteBit register bit value next) -> do
        case value of
            ConstBit High -> do
                line (register ++ " |= (1 << " ++ bit ++ ");")
            ConstBit Low -> do
                line (register ++ " &= ~(1 << " ++ bit ++ ");")
            _ -> do
                (Value x cType _ _) <- genLLI value
                block ("if (" ++ x ++ ") {") $ do
                    line (register ++ " |= (1 << " ++ bit ++ ");")
                block "} else {" $ do
                    line (register ++ " &= ~(1 << " ++ bit ++ ");")
                line "}"
        genLLI next
    (WriteByte register value next) -> do
        (Value x cType _ _) <- genLLI value
        line (register ++ " = " ++ x ++ ";")
        genLLI next
    (WriteWord register value next) -> do
        (Value x cType _ _) <- genLLI value
        line (register ++ " = " ++ x ++ ";")
        genLLI next
    (ReadBit register bit) -> do
        x <- genCVariable "bool"
        line $ x ++ " = (" ++ register ++ " & (1 << " ++ bit ++ ")) == 0U;"
        variable x CBit
    (ReadWord register next) -> do
        x <- genCVariable (cTypeStr CWord)
        line $ x ++ " = " ++ register ++ ";"
        genLLI next
        variable x CWord
    (WaitBit register bit value next) -> do
        case value of
            High -> do
                line $ "while ((" ++ register ++ " & (1 << " ++ bit ++ ")) == 0) {"
                line $ "}"
        genLLI next
    (Const x) -> do
        literal CBit x
    (ConstBit x) -> do
        case x of
            High -> literal CBit "true"
            Low  -> literal CBit "false"
    InputValue -> do
        variable "input_0" CBit
    End -> do
        return Void

genStreamOutputCalling :: [ResultValue] -> Stream -> Gen ()
genStreamOutputCalling results stream = do
    wrappedResults <- forM results $ \result -> case result of
        (Value name cType Literal delay) -> do
            (Value wrappedName wrappedCType Variable _) <- wrap name cType
            return $ Value wrappedName wrappedCType Variable delay
        _ -> do
            return result
    forM_ wrappedResults $ \result -> case result of
        (Value name cType _ delay) -> do
            forM_ (outputs stream) $ \outputStreamName -> do
                generateCall outputStreamName name
            case delay of
                Just x -> do
                    line $ "// Delay assumes a 16MHz clock"
                    line $ "_delay_loop_2(" ++ x ++ ");"
                    line $ "_delay_loop_2(" ++ x ++ ");"
                    line $ "_delay_loop_2(" ++ x ++ ");"
                    line $ "_delay_loop_2(" ++ x ++ ");"
                _ -> return ()
        (FilterVariable name cType condition) -> do
            forM_ (outputs stream) $ \outputStreamName -> do
                block ("if (" ++ condition ++ ") {") $ do
                    generateCall outputStreamName name
                line "}"
        (ToFlatVariable name cType) -> do
            forM_ (outputs stream) $ \outputStreamName -> do
                i <- genCVariable (cTypeStr listSizeCType)
                block ("for (" ++ i ++ " = 0; " ++ i ++ " < " ++ name ++ ".size; " ++ i ++ "++) {") $ do
                    generateCall outputStreamName ("((" ++ cTypeStr cType ++ "*)" ++ name ++ ".values)[" ++ i ++ "]")
                line "}"
        Void -> do
            return ()
    where
        generateCall (n, outputStreamName) resultVariable = do
            line (outputStreamName ++ "(" ++ show n ++ ", (void*)(&" ++ resultVariable ++ "));")

genInit :: Stream -> Gen ()
genInit stream = case body stream of
    (Driver initLLI _) -> do
        genLLI initLLI
        return ()
    _ -> do
        return ()

genInputCall :: Stream -> Gen ()
genInputCall stream = do
    line (name stream ++ "();")

wrap :: String -> CType -> Gen ResultValue
wrap expression cType = do
    name <- genCVariable (cTypeStr cType)
    line $ name ++ " = " ++ expression ++ ";"
    variable name cType

variable :: String -> CType -> Gen ResultValue
variable name cType = return $ Value name cType Variable Nothing

literal :: CType -> String -> Gen ResultValue
literal cType name = return $ Value name cType Literal Nothing

resultType :: [ResultValue] -> CType
resultType vars = case vars of
    (x:y:rest) -> if extract x == extract y
                      then resultType (y:rest)
                      else error "different c types"
    [var]      -> extract var
    []         -> CVoid

extract (Value _ cType _ _) = cType
extract (FilterVariable _ cType _) = cType
extract (ToFlatVariable _ cType) = cType

cTypeStr :: CType -> String
cTypeStr cType = case cType of
    CBit             -> "bool"
    CByte            -> "uint8_t"
    CWord            -> "uint16_t"
    CVoid            -> "void"
    CList _          -> "struct list"
    CTuple itemTypes -> "struct tuple" ++ show (length itemTypes)

genCVariable :: String -> Gen String
genCVariable cType = do
    l <- label
    header $ cType ++ " " ++ l ++ ";"
    return l

genStaticCVariable :: String -> String -> Gen String
genStaticCVariable cType value = do
    l <- label
    header $ "static " ++ cType ++ " " ++ l ++ " = " ++ value ++ ";"
    return l

cFunction :: String -> Gen a -> Gen a
cFunction declaration gen = do
    header $ ""
    header $ declaration ++ ";"
    line $ ""
    x <- block (declaration ++ " {") gen
    line $ "}"
    return x
