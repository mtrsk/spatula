{-# LANGUAGE OverloadedStrings #-}
module Evaluator ( eval ) where

import Types ( Expression(..), Literal(LBool, LInteger, LRational), LetSort(..), Operator(..) )
import qualified Data.Map as Map
import Data.Text ( Text, unpack, pack )
import Utils ( Result, ResultT )
import Text.Printf ( printf )
import Data.Traversable
import SWPrelude

evalWithEnvironment :: EvalEnv -> Expression -> ResultT Value

evalWithEnvironment _ (ELiteral literal) = pure $ VLiteral literal

evalWithEnvironment env (EVariable label) =
  case Map.lookup label env of
    Nothing -> fail $ printf "ERROR: Unbound variable %s in the environment." (unpack label)
    Just var -> return var

evalWithEnvironment env (EAbstraction label _ _ body) =
  pure $ VClosure label body env

evalWithEnvironment env (EApplication fun arg) = do
  funValue <- evalWithEnvironment env fun
  argValue <- evalWithEnvironment env arg
  case funValue of
    VClosure label body closedEnv ->
      let newEnv = Map.insert label argValue closedEnv in
        evalWithEnvironment newEnv body
    VNativeFunction natFun ->
      natFun argValue
    other -> fail $ printf "ERROR: Attempted to apply value %s to %s that it is not a function." (show argValue) (show other)

evalWithEnvironment env (ECondition cond thenBranch elseBranch) = do
  test <- evalWithEnvironment env cond
  case test of
    VLiteral (LBool b) ->
      if b then
        evalWithEnvironment env thenBranch
      else
        evalWithEnvironment env elseBranch
    cond' -> fail $ printf "ERROR: The condition %s is not a bool." (show cond')

evalWithEnvironment env (ELet In bindings body) = do
  let (labels, expressions) = unzip bindings
  evaluatedExpressions <- for expressions (evalWithEnvironment env)
  let newEnv = foldl f env (zip labels evaluatedExpressions)
      f acc (label, expression) = Map.insert label expression acc
  evalWithEnvironment newEnv body

evalWithEnvironment env (ELet Plus [] body) = evalWithEnvironment env body
evalWithEnvironment env (ELet Plus ((label, expr):xs) body) = do
  evaluatedExpression <- evalWithEnvironment env expr
  evalWithEnvironment (Map.insert label evaluatedExpression env) (ELet Plus xs body)

evalWithEnvironment env (EOperation OpPlus [x])  = evalWithEnvironment env x
evalWithEnvironment env (EOperation OpMul [x])   = evalWithEnvironment env x

evalWithEnvironment env (EOperation OpAnd []) = return $ VLiteral (LBool True)
evalWithEnvironment env (EOperation OpAnd [x])   = evalWithEnvironment env x
evalWithEnvironment env (EOperation OpAnd list@(x:xs)) = do
  operand <- evalWithEnvironment env x
  case operand of
    VLiteral (LBool False) -> return $ VLiteral (LBool False)
    VLiteral (LBool True) -> evalWithEnvironment env (EOperation OpAnd xs)
    _ -> fail "This should never happen"

-- TODO: Instead of relying on recursive calls of evalWithEnvironment, let's make an internal function and do the recursion there
evalWithEnvironment env (EOperation OpOr []) = return $ VLiteral (LBool False)
evalWithEnvironment env (EOperation OpOr [x])    = evalWithEnvironment env x
evalWithEnvironment env (EOperation OpOr list@(x:xs)) = do
  operand <- evalWithEnvironment env x
  case operand of
    VLiteral (LBool True) -> return $ VLiteral (LBool False)
    VLiteral (LBool False) -> evalWithEnvironment env (EOperation OpOr xs)
    _ -> fail "This should never happen"

evalWithEnvironment env (EOperation op [x])        = fail $ printf "ERROR: Operator %s does not have a default monoid" (show op)
evalWithEnvironment env (EOperation operator list) = do
  (x:xs) <- for list (evalWithEnvironment env)
  return $ foldl (operatorFunction operator) x xs

evalWithEnvironment env (EOperation operator []) = fail $ printf "ERROR: Operator %s does not have an empty monoid" (show operator) 

evalWithEnvironment env (ETypeAbstraction _ _ _ body) =
  evalWithEnvironment env body

evalWithEnvironment env (ETypeApplication expr _) =
  evalWithEnvironment env expr

operatorFunction :: Operator -> Value -> Value -> Value
operatorFunction OpPlus (VLiteral (LInteger element)) (VLiteral (LInteger acc)) = VLiteral . LInteger $ element + acc
operatorFunction OpPlus (VLiteral (LRational element)) (VLiteral (LRational acc)) = VLiteral . LRational $ element + acc
operatorFunction OpMul (VLiteral (LInteger element)) (VLiteral (LInteger acc)) = VLiteral . LInteger $ element * acc
operatorFunction OpMul (VLiteral (LRational element)) (VLiteral (LRational acc)) = VLiteral . LRational $ element * acc
operatorFunction OpDiv (VLiteral (LInteger element)) (VLiteral (LInteger acc)) = VLiteral . LInteger $ div element acc
operatorFunction OpDiv (VLiteral (LRational element)) (VLiteral (LRational acc)) = VLiteral . LRational $ element / acc
operatorFunction OpMinus (VLiteral (LInteger element)) (VLiteral (LInteger acc)) = VLiteral . LInteger $ element - acc
operatorFunction OpMinus (VLiteral (LRational element)) (VLiteral (LRational acc)) = VLiteral . LRational $ element - acc
operatorFunction op element acc = error $ printf "Error in fold of %s with element %s and accumulator %s" (show op) (show element) (show acc)

eval :: Expression -> ResultT Value
eval = evalWithEnvironment evaluatorPrelude
