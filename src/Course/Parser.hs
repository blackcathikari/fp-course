{-# LANGUAGE NoImplicitPrelude #-}
{-# LANGUAGE ScopedTypeVariables #-}
{-# LANGUAGE InstanceSigs #-}
{-# LANGUAGE OverloadedStrings #-}
{-# LANGUAGE RebindableSyntax #-}

module Course.Parser where

import Course.Core
import Course.Person
import Course.Functor
import Course.Applicative
import Course.Monad
import Course.List
import Course.Optional
import Data.Char

-- $setup
-- >>> :set -XOverloadedStrings
-- >>> import Data.Char(isUpper)

type Input = Chars

data ParseResult a =
    UnexpectedEof
  | ExpectedEof Input -- not used today
  | UnexpectedChar Char
  | UnexpectedString Chars
  | Result Input a
  deriving Eq

instance Show a => Show (ParseResult a) where
  show UnexpectedEof =
    "Unexpected end of stream"
  show (ExpectedEof i) =
    stringconcat ["Expected end of stream, but got >", show i, "<"]
  show (UnexpectedChar c) =
    stringconcat ["Unexpected character: ", show [c]]
  show (UnexpectedString s) =
    stringconcat ["Unexpected string: ", show s]
  show (Result i a) =
    stringconcat ["Result >", hlist i, "< ", show a]
  
instance Functor ParseResult where
  _ <$> UnexpectedEof =
    UnexpectedEof
  _ <$> ExpectedEof i =
    ExpectedEof i
  _ <$> UnexpectedChar c =
    UnexpectedChar c
  _ <$> UnexpectedString s =
    UnexpectedString s
  f <$> Result i a =
    Result i (f a)

-- Function to determine is a parse result is an error.
isErrorResult ::
  ParseResult a
  -> Bool
isErrorResult (Result _ _) =
  False
isErrorResult UnexpectedEof =
  True
isErrorResult (ExpectedEof _) =
  True
isErrorResult (UnexpectedChar _) =
  True
isErrorResult (UnexpectedString _) =
  True

-- | Runs the given function on a successful parse result. Otherwise return the same failing parse result.
onResult ::
  ParseResult a
  -> (Input -> a -> ParseResult b)
  -> ParseResult b
onResult UnexpectedEof _ = 
  UnexpectedEof
onResult (ExpectedEof i) _ = 
  ExpectedEof i
onResult (UnexpectedChar c) _ = 
  UnexpectedChar c
onResult (UnexpectedString s)  _ = 
  UnexpectedString s
onResult (Result i a) k = 
  k i a

data Parser a = P (Input -> ParseResult a)

parse ::
  Parser a
  -> (Input -> ParseResult a)
parse (P p) =
  p

-- | Produces a parser that always fails with @UnexpectedChar@ using the given character.
unexpectedCharParser ::
  Char
  -> Parser a
unexpectedCharParser c =
  P (\_ -> UnexpectedChar c)

--- | Return a parser that always returns the given parse result.
---
--- >>> isErrorResult (parse (constantParser UnexpectedEof) "abc")
--- True
constantParser :: -- ignore this one today
  ParseResult a
  -> Parser a
constantParser =
  P . const



-- | Return a parser that succeeds with a character off the input or fails with an error if the input is empty.
--
-- >>> parse character "abc"
-- Result >bc< 'a'
--
-- >>> isErrorResult (parse character "")
-- True
character ::
  Parser Char
character = P (\i -> case i of 
                      Nil -> UnexpectedEof
                      h:.t -> Result t h)



-- | Parsers can map.
-- Write a Functor instance for a @Parser@.
--
-- >>> parse (toUpper <$> character) "amz"
-- Result >mz< 'A'
instance Functor Parser where
  (<$>) ::
    (a -> b)
    -> Parser a
    -> Parser b
  -- (<$>) f pa = P (\i -> (<$>) f (parse pa i))
  (<$>) f pa = P ((<$>) f . parse pa) -- point free
  --notes:
  -- parse p :: Input -> ParseResult p 
  -- f :: a -> b 



-- | Return a parser that tries the first parser for a successful value.
--
--   * If the first parser succeeds then use this parser.
--
--   * If the first parser fails, try the second parser.
--
-- >>> parse (character ||| pure 'v') ""
-- Result >< 'v'
--
-- >>> parse (constantParser UnexpectedEof ||| pure 'v') ""
-- Result >< 'v'
--
-- >>> parse (character ||| pure 'v') "abc"
-- Result >bc< 'a'
--
-- >>> parse (constantParser UnexpectedEof ||| pure 'v') "abc"
-- Result >abc< 'v'
(|||) ::
  Parser a
  -> Parser a
  -> Parser a
-- (|||) p1 p2 = P (\i -> case (parse p1 i) of 
--                         Result i a -> Result i a
--                         _ -> parse p2 i)
--or:
(|||) = \p1 p2 -> P(\i ->
  let x = parse p1 i 
  in bool x (parse p2 i) (isErrorResult x))
--or:
-- (|||) p1 p2 = P (\i -> case (parse p1 i) of 
--                           r@(Result _ _) -> r
--                           _ -> parse p2 i)
-- notes:
-- data Parser a = P (Input -> ParseResult a)
-- parse :: Parser a -> (Input -> ParseResult a)

infixl 3 |||




-- | Parsers can bind.
-- Return a parser that puts its input into the given parser and
--
--   * if that parser succeeds with a value (a), put that value into the given function
--     then put in the remaining input in the resulting parser.
--
--   * if that parser fails with an error the returned parser fails with that error.
--
-- >>> parse ((\c -> if c == 'x' then character else pure 'v') =<< character) "abc"
-- Result >bc< 'v'
--
-- >>> parse ((\c -> if c == 'x' then character else pure 'v') =<< character) "a"
-- Result >< 'v'
--
-- >>> parse ((\c -> if c == 'x' then character else pure 'v') =<< character) "xabc"
-- Result >bc< 'a'
--
-- >>> isErrorResult (parse ((\c -> if c == 'x' then character else pure 'v') =<< character) "")
-- True
--
-- >>> isErrorResult (parse ((\c -> if c == 'x' then character else pure 'v') =<< character) "x")
-- True
instance Monad Parser where
  (=<<) ::
    (a -> Parser b)
    -> Parser a
    -> Parser b
  -- (=<<) = \f pa -> P (\i -> case parse pa i of 
  --                           Result j a -> parse (f a) j
  --                           _ -> undefined) -- check all cases and return the same 
  (=<<) = \f p -> P (\i -> (onResult (parse p i) (\j a -> parse (f a) j)))


-- notes:
-- data Parser a = P (Input -> ParseResult a)
-- parse :: Parser a -> (Input -> ParseResult a)
-- f :: a -> Parser b 
-- j :: Input 
-- a :: a
-- f a :: Parser b
-- parse pa :: Input -> ParseResult a
-- parse pa i :: ParseResult a 

-- onResult :: ParseResult a -> (Input -> a -> ParseResult b) -> ParseResult b

-- ?? :: ParseResult b




-- | Return a parser that puts its input into the given parser and
--
--   * if that parser succeeds with a value (a), ignore that value
--     but put the remaining input into the second given parser.
--
--   * if that parser fails with an error the returned parser fails with that error.
--
-- /Tip:/ Use @(=<<)@ or @(>>=)@.
--
-- >>> parse (character >>> pure 'v') "abc"
-- Result >bc< 'v'
--
-- >>> isErrorResult (parse (character >>> pure 'v') "")
-- True
(>>>) ::
  Parser a
  -> Parser b
  -> Parser b
(>>>) = (*>)



-- | Write an Applicative functor instance for a @Parser@.
-- /Tip:/ Use @(=<<)@.
--
-- | Return a parser that always succeeds with the given value and consumes no input.
--
-- >>> parse (pure 3) "abc"
-- Result >abc< 3
instance Applicative Parser where
  pure ::
    a
    -> Parser a
  pure a = P (\i -> Result i a)
  (<*>) ::
    Parser (a -> b)
    -> Parser a
    -> Parser b
  (<*>) f p = (=<<) (\i -> (<$>) i p) f 




-- | Return a parser that continues producing a list of values from the given parser.
--
-- /Tip:/ Use @list1@, @pure@ and @(|||)@.
--
-- >>> parse (list character) ""
-- Result >< ""
--
-- >>> parse (list digit) "123abc"
-- Result >abc< "123"
--
-- >>> parse (list digit) "abc"
-- Result >abc< ""
--
-- >>> parse (list character) "abc"
-- Result >< "abc"
--
-- >>> parse (list (character *> pure 'v')) "abc"
-- Result >< "vvv"
--
-- >>> parse (list (character *> pure 'v')) ""
-- Result >< ""
list ::
  Parser a
  -> Parser (List a)
list p = list1 p ||| pure Nil

-- | Return a parser that produces at least one value from the given parser then
-- continues producing a list of values from the given parser (to ultimately produce a non-empty list).
--
-- /Tip:/ Use @(=<<)@, @list@ and @pure@.
--
-- >>> parse (list1 (character)) "abc"
-- Result >< "abc"
--
-- >>> parse (list1 (character *> pure 'v')) "abc"
-- Result >< "vvv"
--
-- >>> isErrorResult (parse (list1 (character *> pure 'v')) "")
-- True
list1 ::
  Parser a
  -> Parser (List a)
list1 p = p >>= (\a -> list p >>= (\b -> pure (a:.b)))



-- | Return a parser that produces a character but fails if
--
--   * The input is empty.
--
--   * The character does not satisfy the given predicate.
--
-- /Tip:/ The @(=<<)@, @unexpectedCharParser@ and @character@ functions will be helpful here.
--
-- >>> parse (satisfy isUpper) "Abc"
-- Result >bc< 'A'
--
-- >>> isErrorResult (parse (satisfy isUpper) "abc")
-- True
satisfy ::
  (Char -> Bool)
  -> Parser Char
-- satisfy f = character >>= \c -> bool (unexpectedCharParser c) (pure c) (f c)
-- satisfy f = character >>= \c -> ((bool unexpectedCharParser pure) =<< (f)) c
-- satisfy f = character >>= ((bool unexpectedCharParser pure) =<< (f))
--notes on types (deconstruction):
-- f :: (->) Char Bool
-- bool unexpectedCharParser pure :: Bool -> (->) Char (Parser Char)
-- =<< :: (Bool -> (->) Char (Parser Char)) -> (->) Char Bool -> (->) Char (Parser Char)

-- satisfy f = character >>= (f >>= (bool unexpectedCharParser pure))
-- satisfy f = character >>= (f >>= (bool unexpectedCharParser pure)) -- lift gdi

--given answer:
satisfy f = character >>= lift3 bool unexpectedCharParser pure f

-- notes:
-- data Parser a = P (Input -> ParseResult a)
-- parse :: Parser a -> (Input -> ParseResult a)
-- parse pa :: Input -> ParseResult a
-- parse pa i :: ParseResult a 
-- character :: Parser Char -- takes Chars 




-- | Return a parser that produces the given character but fails if
--
--   * The input is empty.
--
--   * The produced character is not equal to the given character.
--
-- /Tip:/ Use the @satisfy@ function.
is ::
  Char -> Parser Char
-- is c = satisfy (\i -> (==) i c)
is c = satisfy ((==) c)

-- | Return a parser that produces a character between '0' and '9' but fails if
--
--   * The input is empty.
--
--   * The produced character is not a digit.
--
-- /Tip:/ Use the @satisfy@ and @Data.Char#isDigit@ functions.
digit ::
  Parser Char
digit = satisfy isDigit

--
-- | Return a parser that produces a space character but fails if
--
--   * The input is empty.
--
--   * The produced character is not a space.
--
-- /Tip:/ Use the @satisfy@ and @Data.Char#isSpace@ functions.
space ::
  Parser Char
space = satisfy isSpace

-- | Return a parser that produces one or more space characters
-- (consuming until the first non-space) but fails if
--
--   * The input is empty.
--
--   * The first produced character is not a space.
--
-- /Tip:/ Use the @list1@ and @space@ functions.
spaces1 ::
  Parser Chars
spaces1 = list1 space

-- | Return a parser that produces a lower-case character but fails if
--
--   * The input is empty.
--
--   * The produced character is not lower-case.
--
-- /Tip:/ Use the @satisfy@ and @Data.Char#isLower@ functions.
lower ::
  Parser Char
lower = satisfy isLower

-- | Return a parser that produces an upper-case character but fails if
--
--   * The input is empty.
--
--   * The produced character is not upper-case.
--
-- /Tip:/ Use the @satisfy@ and @Data.Char#isUpper@ functions.
upper ::
  Parser Char
upper = satisfy isUpper

-- | Return a parser that produces an alpha character but fails if
--
--   * The input is empty.
--
--   * The produced character is not alpha.
--
-- /Tip:/ Use the @satisfy@ and @Data.Char#isAlpha@ functions.
alpha ::
  Parser Char
alpha = satisfy isAlpha

-- | Return a parser that sequences the given list of parsers by producing all their results
-- but fails on the first failing parser of the list.
--
-- /Tip:/ Use @(=<<)@ and @pure@.
-- /Tip:/ Optionally use @List#foldRight@. If not, an explicit recursive call.
--
-- >>> parse (sequenceParser (character :. is 'x' :. upper :. Nil)) "axCdef"
-- Result >def< "axC"
--
-- >>> isErrorResult (parse (sequenceParser (character :. is 'x' :. upper :. Nil)) "abCdef")
-- True
sequenceParser ::
  List (Parser a)
  -> Parser (List a)
sequenceParser Nil = pure Nil 
sequenceParser (h:.t) = 
  -- h                >>= (\a ->
  -- sequenceParser t >>= (\b -> 
  -- pure (a:.b)))
--in do notation:
  do
    a <- h
    b <- sequenceParser t
    pure (a:.b)
--notes: because a and b are only on the left side of the arrows, we can use applicative something???
--means we can use lift though, and the number is the number of arrows
--so lift2 here
  --or:
  -- (:.) <$> h <*> sequenceParser t



-- | Return a parser that produces the given number of values off the given parser.
-- This parser fails if the given parser fails in the attempt to produce the given number of values.
--
-- /Tip:/ Use @sequenceParser@ and @List.replicate@.
--
-- >>> parse (thisMany 4 upper) "ABCDef"
-- Result >ef< "ABCD"
--
-- >>> isErrorResult (parse (thisMany 4 upper) "ABcDef")
-- True
thisMany ::
  Int
  -> Parser a
  -> Parser (List a)
-- thisMany = \n p -> sequenceParser (replicate n p)
--replicate n p :: List (Parse a)
--note: to point-free:
-- \n -> sequenceParser . replicate n
--which becomes:
thisMany = (sequenceParser . ) . replicate



-- | This one is done for you.
--
-- /Age: positive integer/
--
-- >>> parse ageParser "120"
-- Result >< 120
--
-- >>> isErrorResult (parse ageParser "abc")
-- True
--
-- >>> isErrorResult (parse ageParser "-120")
-- True
ageParser ::
  Parser Int
ageParser =
  (\k -> case read k of Empty  -> constantParser (UnexpectedString k)
                        Full h -> pure h) =<< (list1 digit)

-- | Write a parser for Person.firstName.
-- /First Name: non-empty string that starts with a capital letter and is followed by zero or more lower-case letters/
--
-- /Tip:/ Use @(=<<)@, @pure@, @upper@, @list@ and @lower@.
--
-- >>> parse firstNameParser "Abc"
-- Result >< "Abc"
--
-- >>> isErrorResult (parse firstNameParser "abc")
-- True
firstNameParser ::
  Parser Chars
firstNameParser = 
  -- do 
  --   a <- satisfy alpha h
  --   b <- t satisfy
  -- upper >>= (\u -> 
  -- list lower >>= (\l ->
  -- pure (u:.l)))
--or:
  lift2 (:.) (upper) (list lower)




-- | Write a parser for Person.surname.
--
-- /Surname: string that starts with a capital letter and is followed by 5 or more lower-case letters./
--
-- /Tip:/ Use @(=<<)@, @pure@, @upper@, @thisMany@, @lower@ and @list@.
--
-- >>> parse surnameParser "Abcdef"
-- Result >< "Abcdef"
--
-- >>> parse surnameParser "Abcdefghijklmnopqrstuvwxyz"
-- Result >< "Abcdefghijklmnopqrstuvwxyz"
--
-- >>> isErrorResult (parse surnameParser "Abc")
-- True
--
-- >>> isErrorResult (parse surnameParser "abc")
-- True
surnameParser ::
  Parser Chars
surnameParser = 
  -- upper >>= (\u -> 
  -- thisMany 5 lower >>= (\v -> 
  -- list lower >>= (\w -> 
  -- pure (u :. v ++ w) )))
  -- lift3 (\u v w -> u :. v ++ w) upper (thisMany 5 lower) (list lower)
  lift3 (((++) .) . (:.)) upper (thisMany 5 lower) (list lower)
  



-- | Write a parser for Person.smoker.
--
-- /Smoker: character that must be @'y'@ or @'n'@/
--
-- /Tip:/ Use @is@ and @(|||)@./
--
-- >>> parse smokerParser "yabc"
-- Result >abc< 'y'
--
-- >>> parse smokerParser "nabc"
-- Result >abc< 'n'
--
-- >>> isErrorResult (parse smokerParser "abc")
-- True
smokerParser ::
  Parser Char
smokerParser = is 'y' ||| is 'n'




-- | Write part of a parser for Person#phoneBody.
-- This parser will only produce a string of digits, dots or hyphens.
-- It will ignore the overall requirement of a phone number to
-- start with a digit and end with a hash (#).
--
-- /Phone: string of digits, dots or hyphens .../
--
-- /Tip:/ Use @list@, @digit@, @(|||)@ and @is@.
--
-- >>> parse phoneBodyParser "123-456"
-- Result >< "123-456"
--
-- >>> parse phoneBodyParser "123-4a56"
-- Result >a56< "123-4"
--
-- >>> parse phoneBodyParser "a123-456"
-- Result >a123-456< ""
phoneBodyParser ::
  Parser Chars
phoneBodyParser = list (digit ||| is '-' ||| is '.')





-- | Write a parser for Person.phone.
--
-- /Phone: ... but must start with a digit and end with a hash (#)./
--
-- /Tip:/ Use @(=<<)@, @pure@, @digit@, @phoneBodyParser@ and @is@.
--
-- >>> parse phoneParser "123-456#"
-- Result >< "123-456"
--
-- >>> parse phoneParser "123-456#abc"
-- Result >abc< "123-456"
--
-- >>> isErrorResult (parse phoneParser "123-456")
-- True
--
-- >>> isErrorResult (parse phoneParser "a123-456")
-- True
phoneParser ::
  Parser Chars
phoneParser = 
  -- digit >>= (\b -> 
  -- phoneBodyParser >>= (\c -> 
  -- is '#' >>= (\_ -> 
  -- pure (b :. c))))
--or:
  -- (\d b -> d :. b) <$>
--becomes:
  (:.) <$>
  digit <*>
  phoneBodyParser <* -- we don't care about the hash value, so we remove the wing from <*>
  is '#'




-- | Write a parser for Person.
--
-- /Tip:/ Use @(=<<)@,
--            @pure@,
--            @(>>>)@,
--            @spaces1@,
--            @ageParser@,
--            @firstNameParser@,
--            @surnameParser@,
--            @smokerParser@,
--            @phoneParser@.
--
-- >>> isErrorResult (parse personParser "")
-- True
-- >>> isErrorResult (parse personParser "12x Fred Clarkson y 123-456.789#")
-- True
-- >>> isErrorResult (parse personParser "123 fred Clarkson y 123-456.789#")
-- True
-- >>> isErrorResult (parse personParser "123 Fred Cla y 123-456.789#")
-- True
-- >>> isErrorResult (parse personParser "123 Fred clarkson y 123-456.789#")
-- True
-- >>> isErrorResult (parse personParser "123 Fred Clarkson x 123-456.789#")
-- True
-- >>> isErrorResult (parse personParser "123 Fred Clarkson y 1x3-456.789#")
-- True
-- >>> isErrorResult (parse personParser "123 Fred Clarkson y -123-456.789#")
-- True
-- >>> isErrorResult (parse personParser "123 Fred Clarkson y 123-456.789")
-- True
-- >>> parse personParser "123 Fred Clarkson y 123-456.789#"
-- Result >< Person {age = 123, firstName = "Fred", surname = "Clarkson", smoker = 'y', phone = "123-456.789"}
-- >>> parse personParser "123 Fred Clarkson y 123-456.789# rest"
-- Result > rest< Person {age = 123, firstName = "Fred", surname = "Clarkson", smoker = 'y', phone = "123-456.789"}--
-- >>> parse personParser "123  Fred   Clarkson    y     123-456.789#"
-- Result >< Person {age = 123, firstName = "Fred", surname = "Clarkson", smoker = 'y', phone = "123-456.789"}
personParser ::
  Parser Person
personParser = 
  -- (\a f l s p -> Person a f l s p) <$>
  Person <$>
  ageParser <*
  spaces1 <*>
  firstNameParser <*
  spaces1 <*>
  surnameParser <*
  spaces1 <*>
  smokerParser <*
  spaces1 <*>
  phoneParser


-- Make sure all the tests pass!

----

-- Did you repeat yourself in `personParser` ? This might help:

(>>=~) ::
  Parser a
  -> (a -> Parser b)
  -> Parser b
(>>=~) p f =
  (p <* spaces1) >>= f

infixl 1 >>=~

-- or maybe this

(<*>~) ::
  Parser (a -> b)
  -> Parser a
  -> Parser b
(<*>~) f a =
  f <*> spaces1 *> a

infixl 4 <*>~
