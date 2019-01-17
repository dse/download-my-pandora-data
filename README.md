# Download My Pandora Data

Pandora does not offer an official way to download your music-related
data that I could find, so I created one.

## Requirements

1.  A Unix-type command line.  I can't guarantee the steps below will
    work in the Windows DOS prompt or PowerShell.
2.  Perl.  Preferably a more recent version.
3.  The following modules from CPAN:
    -   `WebService::Pandora`
    -   `JSON`
    -   `File::Remove`
    -   `URI::Escape`

## How to Use

1.  `mkdir ~/.pandora`
2.  `echo 'youremail@example.com` > ~/.pandora/credentials.txt`
3.  `echo -n 'yourpassword' | perl -MMIME::Base64 -e 'print encode_base64(<>);' >> ~/.pandora/credentials.txt`
4.  `bin/download-my-pandora-data`

The `MIME::Base64` stuff in Step 3 is entirely so users hovering over your
shoulder won't accidentally see your Pandora password.  It is **not** a
form of encryption.

I'll add interactive prompts to the program so it asks you for your email
address and password eventually.  That way your **unencoded** password won't
show up in `~/.bash_history`.  :-)

## What It Does

1.  Creates the `~/.pandora/data` directory.
2.  Puts a bunch of `.json` files there.
3.  The data for your Pandora stations is in a subdirectory called `stations`.

## Best Effort but No Guarantee

I cannot guarantee that this program will download every bit of data
that you need, though I do make my best effort.  This program uses the
CPAN `WebService::Pandora` module and all the methods listed in its
documentation, with all options to provide additional data turned on.
