# ffopportunity (development version)

* Added a `NEWS.md` file to track changes to the package.
* Added `ep_build()` and initial subfunctions to preprocess, predict, and summarise EP
* Added `ep_load_*()` to download release data
* Added `update/` script that uses piggyback to update release data
* Offloaded models to releases ("latest-models", "v1.0.0-models")
* Added download of models to user cache
* Combine variants of ep_load into one function `ep_load()` with arguments
* Rename to ffopportunity
* Include spikes and kneel downs to tie out to official stats with `ep_summarize()`
* Fix YAC bug in pbp_pass data