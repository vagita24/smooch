{-# LANGUAGE OverloadedStrings #-}

module Upload where

import qualified Web.Scotty as S 

import Network.Wai.Parse

import qualified Data.ByteString.Lazy as B
import qualified Data.ByteString.Char8 as BS
import qualified Data.Text.Lazy as LT
import qualified Data.Text as T

import System.FilePath ((</>), takeBaseName, takeExtension)
import System.Directory
import System.Exit

import Control.Monad.Trans.Either
import Control.Monad.IO.Class (liftIO)
import Data.Monoid ((<>))

import KissSet
import Index

import ParseCNF
import Kiss
import Shell
import Data.Aeson.Encode (encode) 

processSet :: [S.File] -> EitherT T.Text IO [KissCell]
processSet files = do
  file <- getFile files
  let fileName = fst file
  let fileContents = snd file
  let staticDir = "static/sets/" <> takeBaseName fileName
  liftIO $ B.writeFile ("static/sets" </> fileName) fileContents
  liftIO $ createDirectoryIfMissing ("create parents" == "false") staticDir
  unzipFile fileName staticDir
  cnf <- getCNF staticDir
  kissData <- getKissData cnf
  kissCels <- getKissCels cnf
  -- just using first palette found for now
  let kissPalette = Prelude.head $ kPalettes kissData
  let json = "var kissJson = " <> encode kissData
  liftIO $ B.writeFile (staticDir <> "/setdata.js") json
  convertCels kissPalette (map celName kissCels) staticDir
  return kissCels

getFile :: [S.File] -> EitherT T.Text IO (String, B.ByteString)
getFile files = EitherT $ return $
  case files of 
    [(_, b)]  -> Right (BS.unpack (fileName b), fileContent b)
    otherwise -> Left "Please upload exactly one file."

getRelDir :: [S.File] -> EitherT T.Text IO FilePath
getRelDir files = do
  file <- getFile files
  let fileName = fst file
  return $ "sets/" ++ takeBaseName fileName

-- for now, only looks at first cnf listed
getCNF :: FilePath -> EitherT T.Text IO String
getCNF dir = do
  files <- liftIO $ getDirectoryContents dir
  let cnfs = filter (\x -> takeExtension x == ".cnf") files 
  case cnfs of
    (x:xs)    -> liftIO $ readFile $ dir </> x
    otherwise -> EitherT $ return $ Left "No configuration file found."

