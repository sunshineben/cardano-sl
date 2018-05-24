-- | Functions for sanity checking the GState DB.

module Pos.GState.SanityCheck
       ( sanityCheckDB
       ) where

import           Universum

import           System.Wlog (WithLogger)
import           UnliftIO (MonadUnliftIO)

import           Pos.DB.Class (MonadDBRead)
import           Pos.DB.GState.Stakes (getRealTotalStake)
import           Pos.Txp.DB (sanityCheckStakes, sanityCheckUtxo)
import           Pos.Util.AssertMode (inAssertMode)
import           Pos.Core (HasGenesisData)

sanityCheckDB ::
       ( MonadMask m
       , WithLogger m
       , MonadDBRead m
       , MonadUnliftIO m
       , HasGenesisData
       )
    => m ()
sanityCheckDB = inAssertMode sanityCheckGStateDB

-- | Check that GState DB is consistent.
sanityCheckGStateDB ::
       forall m.
       ( MonadDBRead m
       , MonadUnliftIO m
       , WithLogger m
       , HasGenesisData
       )
    => m ()
sanityCheckGStateDB = do
    sanityCheckStakes
    sanityCheckUtxo =<< getRealTotalStake
