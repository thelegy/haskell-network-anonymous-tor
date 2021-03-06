-- | Abstract syntax tree used by the 'Parser', including helper functions
--   for traversing the tree.
--
--   __Warning__: This function is used internally by 'Network.Anonymous.Tor'
--                and using these functions directly is unsupported. The
--                interface of these functions might change at any time without
--                prior notice.
--

module Network.Anonymous.Tor.Protocol.Parser.Ast where
import qualified Data.Attoparsec.ByteString as Atto

import qualified Data.ByteString            as BS

-- | A token is a key and can maybe have an associated value
data Token = Token {
  tokenKey :: BS.ByteString,
  tokenValue :: Maybe BS.ByteString
  } deriving (Show, Eq)

-- | A line is just a sequence of tokens -- the 'Parser' ends the chain
--   when a newline is received.
data Line = Line {
  lineStatusCode :: Integer,
  lineMessage :: [Token]
  } deriving (Show, Eq)

-- | Returns true if the key was found
key :: BS.ByteString -- ^ The key to look for
    -> [Token]       -- ^ Tokens to consider
    -> Bool          -- ^ Result
key _ []               = False                   -- Key was not found
key k1 (Token k2 _:xs) = (k1 == k2) || key k1 xs -- If keys match, return true, otherwise enter recursion

-- | Looks up a key and returns the value if found
value :: BS.ByteString       -- ^ Key to look for
      -> [Token]             -- ^ Tokens to consider
      -> Maybe BS.ByteString -- ^ The value if the key was found
value _ []                   = Nothing          -- Key not found!
value k1 (Token k2 v:xs)     = if   k1 == k2    -- This assumes keys are unique
                               then v           -- This returns the value of the key, if any value is associated
                               else value k1 xs -- Otherwise we continue our quest (in recursion)

-- | Retrieves value, and applies it to an Attoparsec parser
valueAs :: Atto.Parser a
        -> BS.ByteString
        -> [Token]
        -> Maybe a
valueAs p k xs =
  let parseValue bs =
        case Atto.parseOnly p bs of
         Left _  -> Nothing
         Right r -> Just r

  in case value k xs of
      Nothing -> Nothing
      Just v  -> parseValue v

-- | Retrieves first line that starts with a certain token
line :: BS.ByteString -- ^ Token key to look for
     -> [Line]        -- ^ Lines to consider
     -> Maybe Line    -- ^ The line that starts with this key, if found
line _ [] = Nothing
line k1 (x:xs) =
  case x of
   Line _ (Token k2 _:_) -> if k1 == k2
                            then Just x
                            else line k1 xs
   _                      -> line k1 xs

-- | Returns status code of a reply.
statusCode :: [Line]
           -> Integer
statusCode = lineStatusCode . head
