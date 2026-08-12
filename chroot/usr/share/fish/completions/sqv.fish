complete -c sqv -l output -d 'Write to FILE or stdout if omitted' -r -F
complete -c sqv -l signature-file -d 'Verify a detached signature file' -r -F
complete -c sqv -l keyring -d 'A keyring' -r -F
complete -c sqv -l not-after -d 'Consider signatures created after TIMESTAMP as invalid' -r
complete -c sqv -l not-before -d 'Consider signatures created before TIMESTAMP as invalid' -r
complete -c sqv -s n -l signatures -d 'The number of valid signatures to return success' -r
complete -c sqv -l policy-as-of -d 'Select the cryptographic policy as of the specified time' -r
complete -c sqv -l message -d 'Verify an inline signed message'
complete -c sqv -l cleartext -d 'Verify a cleartext-signed message'
complete -c sqv -s v -l verbose -d 'Be verbose'
complete -c sqv -s h -l help -d 'Print help (see more with \'--help\')'
complete -c sqv -s V -l version -d 'Print version'
