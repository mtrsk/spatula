{-# LANGUAGE OverloadedStrings #-}
module Parser.Expression where

import Types
import Parser.Types
import Parser.Literal
import Parser.Variable
import Text.Parsec
import Data.Set
import Data.Char
import Data.Monoid

exprLiteral :: ParserT st Expression
exprLiteral = ELiteral <$> anyLiteral

exprVariable :: ParserT st Expression
exprVariable = EVariable <$> anyVariable

exprApplication :: ParserT st Expression
exprApplication = undefined
  
expression :: ParserT st Expression
expression = undefined

openDelimiter :: ParserT st Char
openDelimiter = char '[' <* spaces

closeDelimiter :: ParserT st Char
closeDelimiter = spaces *> char ']' 

exprCondition :: ParserT st Expression
exprCondition = ECondition <$> (openDelimiter *> string "if" *> body) <*> body <*> body <* closeDelimiter
  where body = spaces *> expression <* spaces

-- (defun abstraction ()
--   (parser/map
--    #'ast:make-abstraction/1
--    (parser-header
--     (justRight
--      (seq (char "[") (whitespaces*))
--      (justLeft
--       (seq
--        (justRight (justLeft (prefix "lambda") (whitespaces*)) (parameters))
--        (many+ (justRight (whitespaces+) (expression))))
--       (seq (whitespaces*) (char "]")))))))

-- (defun parameters ()
--   (parser-header
--    (justRight
--     (seq (char "[") (whitespaces*))
--     (justLeft
--      (seq
--       (many*
--        (justLeft
-- 	(seq
-- 	 (justRight
-- 	  (seq (whitespaces*) (char "("))
-- 	  (justRight (whitespaces*) (identifier)))
-- 	 (justLeft
-- 	  (justRight (whitespaces+) (type))
-- 	  (seq (whitespaces*) (char ")"))))
-- 	(whitespaces*)))
--        (optional (typed-variadic)))
--      (seq (whitespaces*) (char "]"))))))

-- fold right from the body adding one argument at the time
exprAbstraction :: ParserT st Expression
exprAbstraction = undefined
