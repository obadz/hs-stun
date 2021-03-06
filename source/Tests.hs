{-# LANGUAGE NoMonomorphismRestriction #-}
{-# LANGUAGE RecordWildCards #-}
module Main where

import           Control.Applicative
import           Control.Monad
import qualified Data.ByteString as BS
import           Data.Serialize
import qualified Data.Text as Text
import           Data.Word
import           Network.Socket
import qualified Network.Stun.Base as Stun
import qualified Network.Stun.Error as Stun
import qualified Network.Stun.MappedAddress as Stun
import           Test.Framework
import           Test.Framework.Providers.QuickCheck2
import           Test.QuickCheck

instance Arbitrary Stun.MessageClass where
    arbitrary = elements [ Stun.Request
                         , Stun.Success
                         , Stun.Failure
                         , Stun.Indication]



checkEncDec method messageClass = let method' = method `mod` (2^12) in
    (method', messageClass) ==
      (Stun.decodeMessageType $ Stun.encodeMessageType method' messageClass)

checkDecEnc word = let word' = word `mod` (2^14) in
        word' == (uncurry Stun.encodeMessageType $ Stun.decodeMessageType word')


test1 = testProperty "checkEncDec" checkEncDec
test2 = testProperty "checkDecEnc" checkDecEnc

instance Arbitrary Stun.Message where
    arbitrary = do
        messageMethod <- (`mod` (2^12)) `liftM` arbitrary
        messageClass <- arbitrary
        transactionID <- liftM3 Stun.TID arbitrary arbitrary arbitrary
        messageAttributes <- arbitrary
        fingerprint <- arbitrary
        return Stun.Message{..}


checkSerializer x = decode (encode x) == Right x

test3 = testProperty "checkSerializer/Message"
            (checkSerializer :: Stun.Message -> Bool)

instance Arbitrary Stun.Attribute where
    arbitrary = liftM2 Stun.Attribute arbitrary (BS.pack `liftM` arbitrary)

test4 = testProperty "checkSerializer/Attribute"
            (checkSerializer :: Stun.Attribute -> Bool)


instance Arbitrary SockAddr where
    arbitrary = do
        fam <- (`mod` 2) <$> (arbitrary :: Gen Int)
        port <- fromIntegral <$> (arbitrary :: Gen Word16)
        case fam of
            1 -> SockAddrInet port <$> arbitrary
            0 -> do
                addr <- (,,,) <$> arbitrary
                              <*> arbitrary
                              <*> arbitrary
                              <*> arbitrary
                return $ SockAddrInet6 port 0 addr 0 -- Flow and scopeID aren't
                                                     -- encoded


instance Arbitrary Stun.MappedAddress where
    arbitrary = Stun.MA <$> arbitrary


instance Arbitrary Stun.TransactionID where
    arbitrary = Stun.TID <$> arbitrary <*> arbitrary <*> arbitrary

test5 = testProperty "checkSerializer/Address"
            (checkSerializer :: Stun.MappedAddress -> Bool)

xorAddressInvolution tid addr = Stun.xorAddress tid (Stun.xorAddress tid addr)
                                  == addr
test6 = testProperty "xorAddressInvolution" xorAddressInvolution

instance Arbitrary Stun.ErrorAttribute where
    arbitrary = do
        code <- choose (300,699)
        textLength <- choose (0,128)
        reason <- Text.pack <$> replicateM textLength arbitrary
        return Stun.ErrorAttribute{..}
test7 = testProperty "checkSerializer/Error"
          (checkSerializer :: Stun.ErrorAttribute -> Bool)

main = defaultMain[ test1
                  , test2
                  , test3
                  , test4
                  , test5
                  , test6
                  , test7
                  ]
