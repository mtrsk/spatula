{-# LANGUAGE OverloadedStrings #-}
module Parser.Declarations where

import Types
import Parser.Types
import Parser.Expressions
import Parser.Utilities
import Text.Parsec
    ( char, string, optionMaybe, (<|>), many, many1, between, parserFail, choice, try, digit, eof, manyTill, anyChar )

fileP :: ParserT st [Declaration]
fileP = many (skip *> declarationP <* skip)

declarationP :: ParserT st Declaration
declarationP = choice $ fmap try [DeclExpr <$> expressionP, defunP, defvalP]

defvalP :: ParserT st Declaration
defvalP = do
  openDelimiter *> skip *> string "define" <* skip
  name <- variableGeneric <* skip
  value <- expressionP <* skip <* closeDelimiter <* skip
  pure $ DeclVal name value

defunP :: ParserT st Declaration
defunP = do
  let couples = (,) <$> (char '(' *> skip *> variableGeneric <* skip) <*> (typeP <* skip <* char ')' <* skip)
  openDelimiter *> skip *> string "defun" <* skip
  name <- variableGeneric <* skip
  args <- openDelimiter *> many1 (skip *> couples) <* closeDelimiter <* skip
  (returnType, body) <- (,) <$> (skip *> char ':' *> skip *> typeP <* skip) <*> expressionP <* closeDelimiter <* skip
  let fun = ($ Nothing) . uncurry EAbstraction
      first = (\(lastText, lastType) -> EAbstraction lastText lastType (Just returnType) body) $ Prelude.last args
      funBody = Prelude.foldr fun first (Prelude.init args)
      (_, types) = unzip args
  pure $ DeclFun name (curriedArrow types returnType) funBody
