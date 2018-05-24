module Test.Pos.Core.CoreGenerators where

import           Universum

import           Cardano.Crypto.Wallet (xsignature)
import           Data.Maybe (fromJust)
import           Data.Text
import           Hedgehog (Gen)
import           Pos.Binary.Core()
import           Pos.Core.Common (Address (..), Coin (..), IsBootstrapEraAddr (..)
                                 , makePubKeyAddress, Script (..))
import           Pos.Core.Txp ( Tx (..), TxIn (..), TxInWitness (..)
                              , TxOut (..), TxSig , TxSigData (..))
import           Pos.Crypto.Configuration
import           Pos.Crypto.Hashing (unsafeHash)
import           Pos.Crypto.Signing (createKeypairFromSeed, parseFullPublicKey, PublicKey(..)
                                    , redeemDeterministicKeyGen, redeemPkBuild, RedeemPublicKey(..)
                                    , RedeemSecretKey(..), redeemSign, RedeemSignature(..), sign
                                    , SecretKey(..), Signature (..), SignTag(..))
import           Pos.Data.Attributes (mkAttributes)
import           Prelude

import qualified Crypto.Sign.Ed25519 as Ed25519
import qualified Hedgehog.Gen as Gen
import qualified Hedgehog.Range as Range



--------------- Hedgehog Core Generators ---------------

-- | Generates `PublicKey` with  empty password.

genPubKey :: Gen PublicKey
genPubKey = do
    seed <- Gen.bytes (Range.singleton 32)
    let (pubk, _) = createKeypairFromSeed seed
    return $ PublicKey pubk


genSecKey :: Gen SecretKey
genSecKey = do
    seed <- Gen.bytes (Range.singleton 32)
    let (_, privk) = createKeypairFromSeed seed
    return $ SecretKey privk

genPubKeyAddr :: Gen Address
genPubKeyAddr = do
    bootBool <- Gen.bool
    pubk <- genPubKey
    return $ makePubKeyAddress (IsBootstrapEraAddr bootBool) pubk

genTxOut :: Gen TxOut
genTxOut = do
    address <- genPubKeyAddr
    coin <- Gen.word64 Range.constantBounded
    return $ TxOut address (Coin coin)

genTxOutList :: Gen (NonEmpty TxOut)
genTxOutList = Gen.nonEmpty (Range.constant 1 10) genTxOut


genTxIn :: Gen TxIn
genTxIn = do
    pubKeyAddr <- genPubKey
    txIndex <- Gen.word32 (Range.constant 1 10)
    return $ TxInUtxo (unsafeHash pubKeyAddr) txIndex

genTxInList :: Gen (NonEmpty TxIn)
genTxInList = Gen.nonEmpty (Range.constant 1 10) genTxIn

genTx :: Gen Tx
genTx = do
    txIns <- Gen.nonEmpty (Range.constant 1 10) genTxIn
    txOuts <- Gen.nonEmpty (Range.constant 1 10) genTxOut
    return $ UnsafeTx txIns txOuts (mkAttributes ())

genTxSigData :: Gen TxSigData
genTxSigData = do
    tx <- genTx
    return $ TxSigData (unsafeHash tx)

genSignTag :: Gen SignTag
genSignTag =  Gen.element [ SignForTestingOnly
                          , SignTx
                          , SignRedeemTx
                          , SignVssCert
                          , SignUSProposal
                          , SignCommitment
                          , SignUSVote
                          , SignMainBlock
                          , SignMainBlockLight
                          , SignMainBlockHeavy
                          , SignProxySK
                          ]

genTxSig :: Gen TxSig
genTxSig = do
    pM <- Gen.int32 Range.constantBounded
    signTag <- genSignTag
    sk <- genSecKey
    txSigData <- genTxSigData
    return $ sign (ProtocolMagic pM) signTag sk txSigData

genPkWit :: Gen TxInWitness
genPkWit = do
    pubk <- genPubKey
    txsig <- genTxSig
    return $ PkWitness pubk txsig

genScript :: Gen Script
genScript = do
    version <- Gen.word16 Range.constantBounded
    sScript <- Gen.bytes (Range.singleton 32)
    return $ Script version sScript

genScriptWit :: Gen TxInWitness
genScriptWit = do
    script1 <- genScript
    script2 <- genScript
    return $ ScriptWitness script1 script2

genRedPubKey :: Gen RedeemPublicKey
genRedPubKey = do
    bytes <- Gen.bytes (Range.singleton 32)
    return $ redeemPkBuild bytes

genRedSecKey :: Gen RedeemSecretKey
genRedSecKey = do
    bytes <- Gen.bytes (Range.singleton 32)
    return . snd $ fromJust (redeemDeterministicKeyGen bytes)

genRedSig :: Gen (RedeemSignature TxSigData)
genRedSig = do
    pMag <- Gen.int32 Range.constantBounded
    tag <- genSignTag
    redSecKey <- genRedSecKey
    txSigData <- genTxSigData
    return $ redeemSign (ProtocolMagic pMag) tag redSecKey txSigData

genRedWit :: Gen TxInWitness
genRedWit = do
    redPubKey <- genRedPubKey
    redSig <- genRedSig
    return $ RedeemWitness redPubKey redSig

genUnkWit :: Gen TxInWitness
genUnkWit = do
    word <- Gen.word8 Range.constantBounded
    bs <- Gen.bytes (Range.constant 0 50)
    return $ UnknownWitnessType word bs


------------------------- Golden Test Data -----------------------------

-- PkWitness

seedBS :: ByteString
seedBS = "nvpbkjoxpmemkgicmqxdixdwrsbhwdtqxhtzipzfwkjzzkwifcgszbqmfjyrxrrg"

-- | `XSignature` constructors are not exported from cardano-crypto.
-- Therefore `TxSig` must be constructed with `xsignature`.

txSig :: TxSig
txSig = case xsignature seedBS of
            Right xsig -> Signature xsig
            Left err -> Prelude.error $ "txSig error:" ++ err

-- | `seedPubK` generated with `formatFullPublicKey` and `genPubKey`.

seedPubK :: Text
seedPubK = "eFZDwMJmAX3KKaRV/zLx2PabIE3un79kQ36oZuKFUMjA6wW5zsmOmvRwWoL8gMfw\
           \+xNz1bSHAZvRt47V+iTb7g=="

pubKey :: PublicKey
pubKey = case parseFullPublicKey seedPubK of
            Right pk -> pk
            Left err -> Universum.error (toText ("Seed public key failed to parse: " :: Text) `Data.Text.append` err)

pkWitness :: TxInWitness
pkWitness = PkWitness pubKey txSig

-- ScriptWitness

scrWitness :: TxInWitness
scrWitness = ScriptWitness (Script 52147 "ootteiijvizitypuleyshqtoihcncwia") (Script 732 "xkuiffugzccekevklqdcvjrkrwrxjwdg")

-- RedeemWitness

redWitPubKey :: RedeemPublicKey
redWitPubKey = RedeemPublicKey $ Ed25519.PublicKey "cnrzviaomratmiowjsrqpjmhlfwnlrnu"

redWitSig :: RedeemSignature TxSigData
redWitSig = RedeemSignature (Ed25519.Signature "34r\GSg\129\DC3\209\228\245]\170\189\158\161\22 \
                                                \ 9\t\150'\249\EM$\226q\225\DC1?\136\194\171\15 \
                                                \ 7\167\136t\248\ff\167\203\222\224\142=?\DC34$ \
                                                \z\228Ev\250\161:\a\148\SO\175\233\239\150\t\CAN\ETX")

redWitness :: TxInWitness
redWitness =  RedeemWitness redWitPubKey redWitSig

-- UnknownTypeWitness

unkWitness :: TxInWitness
unkWitness = UnknownWitnessType 127 "\133\SYNE\STX"
