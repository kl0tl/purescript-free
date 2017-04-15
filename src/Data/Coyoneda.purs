module Data.Coyoneda
  ( Coyoneda(..)
  , CoyonedaF
  , coyoneda
  , unCoyoneda
  , liftCoyoneda
  , lowerCoyoneda
  , hoistCoyoneda
  ) where

import Prelude

import Control.Comonad (class Comonad, extract)
import Control.Extend (class Extend, (<<=))
import Control.Monad.Trans.Class (class MonadTrans)

import Data.Eq (class Eq1, eq1)
import Data.Exists (Exists, runExists, mkExists)
import Data.Ord (class Ord1, compare1)

-- | `Coyoneda` is encoded as an existential type using `Data.Exists`.
-- |
-- | This type constructor encodes the contents of the existential package.
data CoyonedaF f a i = CoyonedaF (i -> a) (f i)

-- | The `Coyoneda` `Functor`.
-- |
-- | `Coyoneda f` is a `Functor` for any type constructor `f`. In fact,
-- | it is the _free_ `Functor` for `f`, i.e. any natural transformation
-- | `nat :: f ~> g`, can be factor through `liftCoyoneda`.  The natural
-- | transformation from `Coyoneda f ~> g` is given by `lowerCoyoneda <<<
-- | hoistCoyoneda nat`:
-- | ```purescript
-- | lowerCoyoneda <<< hoistCoyoneda nat <<< liftCoyoneda $ fi
-- | = lowerCoyoneda (hoistCoyoneda nat (Coyoneda $ mkExists $ CoyonedaF id fi))    (by definition of liftCoyoneda)
-- | = lowerCoyoneda (coyoneda id (nat fi))                                         (by definition of hoistCoyoneda)
-- | = unCoyoneda map (coyoneda id (nat fi))                                        (by definition of lowerCoyoneda)
-- | = unCoyoneda map (Coyoneda $ mkExists $ CoyonedaF  id (nat fi))                (by definition of coyoneda)
-- | = map id (nat fi)                                                              (by definition of unCoyoneda)
-- | = nat fi                                                                       (since g is a Functor)
-- | ```
newtype Coyoneda f a = Coyoneda (Exists (CoyonedaF f a))

instance eqCoyoneda :: (Functor f, Eq1 f, Eq a) => Eq (Coyoneda f a) where
  eq x y = lowerCoyoneda x `eq1` lowerCoyoneda y

instance eq1Coyoneda :: (Functor f, Eq1 f) => Eq1 (Coyoneda f) where
  eq1 = eq

instance ordCoyoneda :: (Functor f, Ord1 f, Ord a) => Ord (Coyoneda f a) where
  compare x y = lowerCoyoneda x `compare1` lowerCoyoneda y

instance ord1Coyoneda :: (Functor f, Ord1 f) => Ord1 (Coyoneda f) where
  compare1 = compare

instance functorCoyoneda :: Functor (Coyoneda f) where
  map f (Coyoneda e) = runExists (\(CoyonedaF k fi) -> coyoneda (f <<< k) fi) e

instance applyCoyoneda :: Apply f => Apply (Coyoneda f) where
  apply f g = liftCoyoneda $ lowerCoyoneda f <*> lowerCoyoneda g

instance applicativeCoyoneda :: Applicative f => Applicative (Coyoneda f) where
  pure = liftCoyoneda <<< pure

instance bindCoyoneda :: Bind f => Bind (Coyoneda f) where
  bind (Coyoneda e) f =
    liftCoyoneda $
      runExists (\(CoyonedaF k fi) -> lowerCoyoneda <<< f <<< k =<< fi) e

-- | When `f` is a Monad then it is a functor as well.  In this case
-- | `liftCoyoneda` is not only a functor isomorphism but also a monad
-- | isomorphism, i.e. the following law holds
-- | ```purescript
-- | liftCoyoneda fa >>= liftCoyoneda <<< g = liftCoyoneda $ fa >>= g
-- | ```
instance monadCoyoneda :: Monad f => Monad (Coyoneda f)

instance monadTransCoyoneda :: MonadTrans Coyoneda where
  lift = liftCoyoneda

instance extendCoyoneda :: Extend w => Extend (Coyoneda w) where
  extend f (Coyoneda e) =
    runExists (\(CoyonedaF k fi) -> liftCoyoneda $ f <<< coyoneda k <<= fi) e

-- | As in the monad case: if `w` is a comonad, then it is a functor, thus
-- | `liftCoyoneda` is an iso of functors, but moreover it is an iso of
-- | comonads, i.e. the following law holds:
-- | ```purescript
-- | g <<= liftCoyoneda w = liftCoyoneda $ g <<< liftCoyoneda <<= w
-- | ```
instance comonadCoyoneda :: Comonad w => Comonad (Coyoneda w) where
  extract (Coyoneda e) = runExists (\(CoyonedaF k fi) -> k $ extract fi) e

-- | Construct a value of type `Coyoneda f b` from a mapping function and a
-- | value of type `f a`.
coyoneda :: forall f a b. (a -> b) -> f a -> Coyoneda f b
coyoneda k fi = Coyoneda $ mkExists $ CoyonedaF k fi

-- | Deconstruct a value of `Coyoneda a` to retrieve the mapping function and
-- | original value.
unCoyoneda :: forall f g a. (forall b. (b -> a) -> f b -> g a) -> Coyoneda f a -> g a
unCoyoneda f (Coyoneda e) = runExists (\(CoyonedaF k fi) -> f k fi) e

-- | Lift a value described by the type constructor `f` to `Coyoneda f`.
-- |
-- | Note that for any `f` `liftCoyoneda` has a right inverse
-- | `lowerCoyoneda`:
-- | ```purescript
-- | liftCoyoneda <<< lowerCoyoneda $ (Coyoneda e)
-- | = liftCoyoneda <<< unCoyoneda map $ (Coyonead e)
-- | = liftCoyonead (runExists (\(CoyonedaF k fi) -> map k fi) e)
-- | = liftCoyonead (Coyoneda e)
-- | = coyoneda id (Coyoneda e)
-- | = Coyoneda e
-- | ```
-- | Moreover if `f` is a `Functor` then `liftCoyoneda` is an isomorphism of
-- | functors with inverse `lowerCoyoneda`:  we already showed that
-- | `lowerCoyoneda <<< hoistCoyoneda id = lowerCoyoneda` is its left inverse
-- | whenever `f` is a functor.
liftCoyoneda :: forall f. f ~> Coyoneda f
liftCoyoneda = coyoneda id

-- | Lower a value of type `Coyoneda f a` to the `Functor` `f`.
lowerCoyoneda :: forall f. Functor f => Coyoneda f ~> f
lowerCoyoneda = unCoyoneda map

-- | Use a natural transformation to change the generating type constructor of a
-- | `Coyoneda`.
hoistCoyoneda :: forall f g. (f ~> g) -> Coyoneda f ~> Coyoneda g
hoistCoyoneda nat (Coyoneda e) =
  runExists (\(CoyonedaF k fi) -> coyoneda k (nat fi)) e
