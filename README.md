# SwiftlyDotEnv

A .env file loader for Swift. I know there are already several out there, but do the others allow you to use just about any format to store your env vars?! I'm honestly asking. I don't know. I doubt it. Most that I've dealt with require some sort of `key=value` per line format (and that is the default included here), but what if you want json or yaml? Do quotes get interpretted or are they literal? What if there are multiple `=`? What if your value has multiple lines? You decide! (details on the defaults are in the docs, but it's the simplest of each of these options.) What about some values that HAVE to be in the env file or the app won't function? You can specify any required keys in the loader, or it will throw (and report the missing values!)

Just pass in a custom serializer closure to the `SwiftlyDotEnv.loadDotEnv` method that takes `Data` in and returns a `[String: String]` and you're golden. Magic! This could be a `JSONDecoder`, a `PropertyListSerializer`, or some yaml or toml library. Of course you're not limited to those, but I think you get the idea.

### Usage

1. `https://github.com/mredig/SwiftlyDotEnv.git` in your swift package dependencies. You know the drill by now. The latest version as of this writing is `0.2.3` ish. It's pretty simple so it probably won't get (or need) many (any?) updates.
1. `import SwiftlyDotEnv`
1. Make sure your env file(s) are named `.env` or `.env.[envNameNoBrackets]`
1. As early as you can in your project (at the very least, before you need any env vars), run `try SwiftlyDotEnv.loadDotEnv()`
	* either pass in the name of your env here or set it in the traditional env as `DOTENV=[yourEnvNameNoBrackets]`
1. Set `SwiftlyDotEnv.preferredEnvironment` to have it prioritize your preferred preference. (Defaults to `.dotEnvFileFirst`)
1. Henceforth, replace any usage of `ProcessInfo.processInfo.environment["EnVKeY"]` with `SwiftlyDotEnv["EnVKeY"]`
1. If you need to, you can also access the raw .env file dict at `SwiftlyDotEnv.environment` (does not include the system app launched environment)


### Docs
All properties and methods are documented inline in code. Either reference the code directly or use Xcode's Option-Click for docs.

### Contribution

* Would be nice to have more flexibility on naming. Something like allowing env names either before or after the `.env` name instead of requiring it afterwards, or even allowing entirely custom names (but keeping the API as similar as possible)
* I don't have any ideas off the top of my head, but perhaps allowing required values to not return optionals? They've been validated in the loading step, so we are good on them existing.
* Update the readme to make the `preferredEnvironment` usage line even more difficult for those with a lisp to say out loud. (no disparaging lisp people - p is just a funny sounding letter. Not as funny as K sounds though!)
* Perhaps something to allow type safe, non string values? That'd be neat.