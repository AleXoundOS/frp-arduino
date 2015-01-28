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

data ResultValue = Value String CType Storage
                 | FilterVariable String CType String
                 | ToFlatVariable String CType

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
    forM_ [2] $ \n -> do
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
    (Driver _ bodyLLI)     -> genLLI bodyLLI
    (Transform expression) -> genExpression inputMap False expression

genStreamOutputCalling :: [ResultValue] -> Stream -> Gen ()
genStreamOutputCalling results stream = do
    wrappedResults <- forM results $ \result -> case result of
        (Value name cType Literal) -> do
            [Value wrappedName wrappedCType Variable] <- wrap name cType
            return $ Value wrappedName wrappedCType Variable
        _ -> do
            return result
    forM_ (outputs stream) $ \outputStreamName -> do
        forM_ wrappedResults $ \result -> case result of
            (Value name cType _) -> do
                generateCall outputStreamName name
            (FilterVariable name cType condition) -> do
                block ("if (" ++ condition ++ ") {") $ do
                    generateCall outputStreamName name
                line "}"
            (ToFlatVariable name cType) -> do
                i <- genCVariable (cTypeStr listSizeCType)
                block ("for (" ++ i ++ " = 0; " ++ i ++ " < " ++ name ++ ".size; " ++ i ++ "++) {") $ do
                    generateCall outputStreamName ("((" ++ cTypeStr cType ++ "*)" ++ name ++ ".values)[" ++ i ++ "]")
                line "}"
    where
        generateCall (n, outputStreamName) resultVariable = do
            line (outputStreamName ++ "(" ++ show n ++ ", (void*)(&" ++ resultVariable ++ "));")

genExpression :: M.Map Int CType -> Bool -> Expression -> Gen [ResultValue]
genExpression inputMap static expression = case expression of
    (Not operand) -> do
        [Value result CBit _] <- genExpression inputMap static operand
        literal ("!(" ++ result ++ ")") CBit
    (Even operand) -> do
        [Value result CWord _] <- genExpression inputMap static operand
        literal ("(" ++ result ++ ") % 2 == 0") CBit
    (Greater left right) -> do
        [Value leftResult  CWord _] <- genExpression inputMap static left
        [Value rightResult CWord _] <- genExpression inputMap static right
        literal (leftResult ++ " > " ++ rightResult) CBit
    (Add left right) -> do
        [Value leftResult  CWord _] <- genExpression inputMap static left
        [Value rightResult CWord _] <- genExpression inputMap static right
        literal (leftResult ++ " + " ++ rightResult) CWord
    (Sub left right) -> do
        [Value leftResult  CWord _] <- genExpression inputMap static left
        [Value rightResult CWord _] <- genExpression inputMap static right
        literal (leftResult ++ " - " ++ rightResult) CWord
    (Input value) -> do
        variable ("input_" ++ show value) (inputMap M.! value)
    (ByteConstant value) -> do
        literal (show value) CByte
    (BoolToBit operand) -> do
        genExpression inputMap static operand
    (IsHigh operand) -> do
        genExpression inputMap static operand
    (BitConstant value) -> do
        case value of
            High -> literal "true" CBit
            Low  -> literal "false" CBit
    (Many values) -> do
        x <- mapM (genExpression inputMap static) values
        return $ concat x
    (ListConstant values) -> do
        x <- mapM (genExpression inputMap static) values
        let exprs = concat x
        temp <- genCVariable "struct list"
        v <- label
        header $ cTypeStr (resultType exprs) ++ " " ++ v ++ "[" ++ show (length exprs) ++ "];"
        forM (zip [0..] exprs) $ \(i, (Value x _ _)) -> do
            line $ v ++ "[" ++ show i ++ "] = " ++ x ++ ";"
        line $ temp ++ ".size = " ++ show (length exprs) ++ ";"
        line $ temp ++ ".values = (void*)" ++ v ++ ";"
        variable temp (CList $ resultType exprs)
    (TupleValue n tuple) -> do
        [Value name (CTuple cTypes) _] <- genExpression inputMap static tuple
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
                    [Value cExpression cType _] <- genExpression inputMap static value
                    name <- genStaticCVariable (cTypeStr cType) cExpression
                    return $ Value name cType Variable
                let res = concat (
                                 [ "{ "
                                 ]
                                 ++
                                 intersperse ", " (map (\(n, (Value name _ _)) -> ".value" ++ show n ++ " = (void*)&" ++ name) (zip [0..] valueVariables))
                                 ++
                                 [ " }"
                                 ]
                                 )
                variable res (CTuple $ map extract valueVariables)
            else do
                valueVariables <- forM values $ \value -> do
                    [Value cExpression cType _] <- genExpression inputMap static value
                    [x] <- wrap cExpression cType
                    return x
                name <- genCVariable ("struct tuple" ++ show (length valueVariables))
                forM_ (zip [0..] valueVariables) $ \(n, (Value x _ _)) ->
                    line $ name ++ ".value" ++ show n ++ " = (void*)&" ++ x ++ ";"
                variable name (CTuple $ map extract valueVariables)
    (NumberToByteArray operand) -> do
        [Value r CWord _] <- genExpression inputMap static operand
        charBuf <- label
        header $ cTypeStr CByte ++ " " ++ charBuf ++ "[20];"
        line $ "snprintf(" ++ charBuf ++ ", 20, \"%d\", " ++ r ++ ");"
        temp <- genCVariable "struct list"
        line $ temp ++ ".size = strlen(" ++ charBuf ++ ");"
        line $ temp ++ ".values = " ++ charBuf ++ ";"
        variable temp (CList CByte)
    (WordConstant value) -> do
        literal (show value) CWord
    (If conditionExpression trueExpression falseExpression) -> do
        [Value conditionResult CBit _] <- genExpression inputMap static conditionExpression
        [Value trueResult cType _] <- genExpression inputMap static trueExpression
        [Value falseResult cType _] <- genExpression inputMap static falseExpression
        temp <- genCVariable (cTypeStr cType)
        block ("if (" ++ conditionResult ++ ") {") $ do
            line $ temp ++ " = " ++ trueResult ++ ";"
        block "} else {" $ do
            line $ temp ++ " = " ++ falseResult ++ ";"
        line $ "}"
        variable temp cType
    (Fold expression startValue) -> do
        [Value startValueResult cType _] <- genExpression inputMap True startValue
        header $ "static " ++ cTypeStr cType ++ " input_1 = " ++ startValueResult ++ ";"
        [Value expressionResult cTypeNothing _] <- genExpression (M.insert 1 cType inputMap) static expression
        genCopy "input_1" expressionResult cType
        variable "input_1" cTypeNothing
    (Filter conditionExpression) -> do
        [Value conditionResult CBit _] <- genExpression inputMap static conditionExpression
        [Value valueResult cType _] <- genExpression inputMap static (Input 0)
        temp <- genCVariable "bool"
        line $ temp ++ " = false;"
        block ("if (" ++ conditionResult ++ ") {") $ do
            line $ temp ++ " = true;"
        line $ "}"
        return [FilterVariable valueResult cType temp]
    (Flatten expression) -> do
        [Value x (CList a) _] <- genExpression inputMap static expression
        return [ToFlatVariable x a]

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

wrap :: String -> CType -> Gen [ResultValue]
wrap expression cType = do
    name <- genCVariable (cTypeStr cType)
    line $ name ++ " = " ++ expression ++ ";"
    variable name cType

variable :: String -> CType -> Gen [ResultValue]
variable name cType = return [Value name cType Variable]

literal :: String -> CType -> Gen [ResultValue]
literal name cType = return [Value name cType Literal]

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

genLLI :: LLI -> Gen [ResultValue]
genLLI lli = case lli of
    (WriteBit register bit value next) -> do
        case value of
            ConstBit High -> do
                line (register ++ " |= (1 << " ++ bit ++ ");")
            ConstBit Low -> do
                line (register ++ " &= ~(1 << " ++ bit ++ ");")
            _ -> do
                [Value x cType _] <- genLLI value
                block ("if (" ++ x ++ ") {") $ do
                    line (register ++ " |= (1 << " ++ bit ++ ");")
                block "} else {" $ do
                    line (register ++ " &= ~(1 << " ++ bit ++ ");")
                line "}"
        genLLI next
    (WriteByte register value next) -> do
        [Value x cType _] <- genLLI value
        line (register ++ " = " ++ x ++ ";")
        genLLI next
    (WriteWord register value next) -> do
        [Value x cType _] <- genLLI value
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
        literal x CBit
    (ConstBit x) -> do
        case x of
            High -> literal "true"  CBit
            Low  -> literal "false" CBit
    InputValue -> do
        variable "input_0" CBit
    End -> do
        return []

resultType :: [ResultValue] -> CType
resultType vars = case vars of
    (x:y:rest) -> if extract x == extract y
                      then resultType (y:rest)
                      else error "different c types"
    [var]      -> extract var
    []         -> CVoid

extract (Value _ cType _) = cType
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
