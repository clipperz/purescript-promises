module Control.Monad.Promise
  ( Promise
  , PurePromise
  , promise
  , then'
  , resolve
  , catch
  , reject
  , race
  , all
  , delay
  , runPromise
  , module Exports
  ) where

import Prelude

import Control.Monad.Eff (Eff, kind Effect)
import Control.Monad.Eff.Class (class MonadEff)
import Control.Monad.Eff.Exception (Error)
import Control.Monad.Error.Class (class MonadError, class MonadThrow)
import Control.Monad.Promise.Unsafe (class Deferred, undefer)
import Control.Monad.Promise.Unsafe (class Deferred) as Exports
import Data.Array as Array
import Data.Foldable (class Foldable)
import Data.Function.Uncurried (Fn2, Fn3, mkFn2, runFn2, runFn3)
import Data.Monoid (class Monoid, mempty)
import Data.Time.Duration (Milliseconds)
import Data.Unfoldable (class Unfoldable)

foreign import data Promise :: # Effect -> Type -> Type

type PurePromise a = forall r. Promise r a

foreign import promiseImpl :: forall r a b c.
  (Fn2 (a -> c) (b -> c) c) -> Promise r a

promise :: forall r a c. Deferred => ((a -> c) -> (Error -> c) -> c) -> Promise r a
promise k = promiseImpl (mkFn2 k)

foreign import thenImpl
  :: forall r a b c. Fn3
    (Promise r a)
    (a -> Promise r b)
    (c -> Promise r b)
    (Promise r b)

thenn
  :: forall r a b c. (a -> Promise r b)
  -> (c -> Promise r b)
  -> Promise r a
  -> Promise r b
thenn succ err p =
  let then'' = runFn3 thenImpl
   in then'' p succ err

then' :: forall r a b. Deferred => (a -> Promise r b) -> Promise r a -> Promise r b
then' = flip thenn reject

foreign import resolveImpl
  :: forall r a. a -> Promise r a

resolve :: forall r a. a -> Promise r a
resolve = resolveImpl

foreign import catchImpl
  :: forall r a b c. Fn2
  (Promise r a)
  (c -> Promise r b)
  (Promise r b)

catchAnything
  :: forall r a c. Promise r a
  -> (c -> Promise r a)
  -> Promise r a
catchAnything = runFn2 catchImpl

catch :: forall r a. Deferred => Promise r a -> (Error -> Promise r a) -> Promise r a
catch = catchAnything

foreign import rejectImpl :: forall r b c. c -> Promise r b

reject :: forall r b. Deferred => Error -> Promise r b
reject = rejectImpl

foreign import allImpl :: forall r a. Array (Promise r a) -> Promise r (Array a)

all :: forall f g r a. Deferred => Foldable f => Unfoldable g => f (Promise r a) -> Promise r (g a)
all = map Array.toUnfoldable <<< allImpl <<< Array.fromFoldable

foreign import raceImpl :: forall r a. Array (Promise r a) -> Promise r a

-- | Note that while promise semantics say that `race xs` resolves to the first
-- | `x` in `xs` to resolve, `race xs` won't terminate until each promise is
-- | settled.
-- | In addition, if `Array.fromFoldable xs` is `[]`, `race xs` will never settle.
race :: forall f r a. Deferred => Foldable f => f (Promise r a) -> Promise r a
race = raceImpl <<< Array.fromFoldable

foreign import delayImpl
  :: forall r a. Fn2
  a
  Milliseconds
  (Promise r a)

delay :: forall r a. Deferred => Milliseconds -> a -> Promise r a
delay = flip (runFn2 delayImpl)

foreign import promiseToEffImpl
  :: forall eff a b c. Fn3
  (Promise eff a)
  (a -> Eff eff b)
  (c -> Eff eff b)
  (Eff eff Unit)

runPromise
  :: forall eff a b. (a -> Eff eff b)
  -> (Error -> Eff eff b)
  -> (Deferred => Promise eff a)
  -> Eff eff Unit
runPromise onSucc onErr p = runFn3 promiseToEffImpl (undefer p) onSucc onErr

instance functorPromise :: Deferred => Functor (Promise r) where
  map :: forall r a b. Deferred => (a -> b) -> Promise r a -> Promise r b
  map f promise = promise # then' \ a -> resolve (f a)

instance applyPromise :: Deferred => Apply (Promise r) where
  apply :: forall r a b. Deferred => Promise r (a -> b) -> Promise r a -> Promise r b
  apply pf pa =
    pf # then' \ f -> pa # then' \ a -> resolve (f a)

instance applicativePromise :: Deferred => Applicative (Promise r) where
  pure = resolve

instance bindPromise :: Deferred => Bind (Promise r) where
  bind :: forall r a b. Deferred => Promise r a -> (a -> Promise r b) -> Promise r b
  bind = flip then'

instance monadPromise :: Deferred => Monad (Promise r)

instance monadThrowPromise :: Deferred => MonadThrow Error (Promise r) where
  throwError :: forall r a. Deferred => Error -> Promise r a
  throwError = reject

instance monadErrorPromise :: Deferred => MonadError Error (Promise r) where
  catchError :: forall r a. Deferred => Promise r a -> (Error -> Promise r a) -> Promise r a
  catchError = catch

instance semigroupPromise :: (Deferred, Semigroup a) => Semigroup (Promise r a) where
  append :: forall r a. Deferred => Semigroup a => Promise r a -> Promise r a -> Promise r a
  append a b = append <$> a <*> b

instance monoidPromise :: (Deferred, Monoid a) => Monoid (Promise r a) where
  mempty :: forall r a. Deferred => Monoid a => Promise r a
  mempty = resolve mempty

foreign import liftEffImpl :: forall eff a. Eff eff a -> Promise eff a
instance monadEffPromise :: Deferred => MonadEff r (Promise r) where
  liftEff :: forall eff a. Deferred => Eff eff a -> Promise eff a
  liftEff = liftEffImpl
