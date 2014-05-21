{-# LANGUAGE OverloadedStrings #-}

module Main where

import           Conduit
import           Control.Applicative
import           Control.Monad
import           Data.Maybe                  (fromMaybe)
import qualified Data.Text                   as TS
import qualified Data.Text.Lazy              as TL
import           Filesystem                  (isDirectory, isFile)
import           Filesystem.Path.CurrentOS   ((</>))
import qualified Filesystem.Path.CurrentOS   as FP
import           Network.HTTP.Types.Status
import           Network.Socket
import           Network.Wai.Handler.FastCGI
import           Prelude                     hiding (FilePath, concat)
import           Web.Scotty

main :: IO ()
main = withSocketsDo $ scottyApp app >>= run

app :: ScottyM ()
app = do
    get "/cgroups" $ do
        hasParams <- (not . null) <$> params
        when hasParams next
        cgroups <- resource $
            sourceDirectoryDeep False cgroups_mount
                $= filterC (\x -> FP.filename x == "tasks")
                $= mapC tasksPathToGroupName
                $$ sinkList
        json cgroups

    get "/cgroups" $ do
        cgroup <- param "name"
        withCGroup cgroup $ \tasksPath -> do
            tasks <- resource $
                sourceFile tasksPath
                    $= linesUnboundedC
                    $$ sinkList
            json (tasks :: [TL.Text])

    put "/cgroups" $ do
        cgroup  <- param "name"
        pid <- param "pid"
        withCGroup cgroup $ \tasksPath -> do
            processExists <- liftIO $ isDirectory ("/proc" </> FP.decodeString pid)
            if processExists
                then do
                    resource $ yield pid $$ sinkFile tasksPath
                    json ()
                else invalidEntity "Process ID" pid
  where
    cgroups_mount = "/sys/fs/cgroup/" :: FP.FilePath

    tasksPathToGroupName = TS.dropWhileEnd (== '/')
                         . TS.pack
                         . FP.encodeString
                         . (\path -> fromMaybe path $ FP.stripPrefix cgroups_mount path)
                         . FP.parent

    resource = liftIO . runResourceT

    invalidEntity ty val = do
        status notFound404
        text (TL.concat [ty, "\"", TL.pack val, "\" does not exist."])

    withCGroup :: String -> (FP.FilePath -> ActionM ()) -> ActionM ()
    withCGroup cgroup f = do
        let dir = cgroups_mount </> FP.decodeString cgroup
            tasksPath = dir </> "tasks"
        dirExists <- liftIO $ isDirectory dir
        if dirExists
            then do
                fileExists <- liftIO $ isFile tasksPath
                if fileExists
                    then f tasksPath
                    else invalidEntity "CGroup" cgroup
            else invalidEntity "CGroup" cgroup
