{-# LANGUAGE OverloadedStrings #-}
module Evaluator ( eval ) where

import Types ( Expression(..), Literal(LBool), LetSort(..) )
import qualified Data.Map as Map
import Data.Text ( Text, unpack, pack )
import Utils ( Result )
import Text.Printf ( printf )
import Data.Traversable
import SWPrelude

evalWithEnvironment :: EvalEnv -> Expression -> Result Value

evalWithEnvironment _ (ELiteral literal) = pure $ VLiteral literal

evalWithEnvironment env (EVariable label) =
  case Map.lookup label env of
    Nothing -> Left $ pack $ printf "ERROR: Unbound variable %s in the environment." (unpack label)
    Just var -> Right var

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
    other -> Left $ pack $ printf "ERROR: Attempted to apply value %s to %s that it is not a function." (show argValue) (show other)

evalWithEnvironment env (ECondition cond thenBranch elseBranch) = do
  test <- evalWithEnvironment env cond
  case test of
    VLiteral (LBool b) ->
      if b then
        evalWithEnvironment env thenBranch
      else
        evalWithEnvironment env elseBranch
    cond' -> Left $ pack $ printf "ERROR: The condition %s is not a bool." (show cond')

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

--evalWithEnvironment env (ELet Star bindings@((label, expr):_) _) = undefined

evalWithEnvironment env (ETypeAbstraction _ _ _ body) =
  evalWithEnvironment env body

evalWithEnvironment env (ETypeApplication expr _) =
  evalWithEnvironment env expr

eval :: Expression -> Result Value
eval = evalWithEnvironment evaluatorPrelude