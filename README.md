# CollectionsDataGooglecodeToGithub

Lightweight command-line gem used to import Google Code "centre-collections" issues into GitHub issues system.
This project was created specially to transfer "centre-collections" issues and is not intended for direct reuse on other repository.
Issues are read from the generated Google Takeout document.

WARNING: The issues have been split on 2 different projects: MT-data and MT-controlled-vocabulary based on labels assigned in GoolgeCode.

## Installation

Bundle:

    $ bundle

## Limitation
 * Can only work with one GitHub user at the time using GitHub access token
 * Sleeps between GitHub API call to avoid hitting the number of call limit (this could still happen if you have > 150 issues)
 * Does not handle merged issues, they will be skipped and flagged
 * Does not handle attachments, they will be ignored (see source code if you want to display them)
 * Comments are pushed to GitHub in order meaning that, more than one run could be necessary in case a discussion occurred on GoogleCode
 * Coming from the Java world (cgendreau), the code is not fully using a proper Ruby coding style (e.g. https://github.com/bbatsov/ruby-style-guide) yet

## Usage

    $ bundle exec bin/vascan_data_googlecode_to_github help
    vascan_data_googlecode_to_github inspect --input=INPUT               # Inspect the GoogleCode json document
    vascan_data_googlecode_to_github dryrun --input=INPUT --token=TOKEN  # test and output result as text
    vascan_data_googlecode_to_github upload --input=INPUT --token=TOKEN  # run and upload issues/comments to GitHub
    vascan_data_googlecode_to_github inspect_states                      # Inspect transfer state json document

