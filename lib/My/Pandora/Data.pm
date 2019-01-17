package My::Pandora::Data;
use warnings;
use strict;
use v5.10.0;

use JSON qw();
use Storable qw(dclone);
use URI::Escape qw(uri_escape_utf8);
use Data::Dumper qw(Dumper);
use File::Spec::Functions qw(rel2abs);

use Moo;

has 'dataDir' => (is => 'rw', default => "$ENV{HOME}/.pandora/data");
has 'format'  => (is => 'rw', default => 'text');
has 'json'    => (is => 'rw', lazy => 1, default => sub {
                      my $json = JSON->new();
                      $json->pretty(1);
                      return $json;
                  });

use constant UNSAFE => '^' . join('', map { quotemeta($_) }
                                      grep { index('/\\"*:<>?|', $_) == -1 }
                                      map { chr($_) }
                                      (32 .. 126));

sub listData {
    my ($self) = @_;
    $self->listBookmarks();
    $self->listStations();
}

sub listBookmarks {
    my ($self) = @_;
    my $data = $self->readFile("bookmarks.json");
    my $artists = delete $data->{artists};
    if (scalar @$artists) {
        if ($self->format eq 'markdown') {
            say "# Artist Bookmarks";
            say '';
        }
        foreach my $artist (@$artists) {
            delete $artist->{bookmarkToken};
            delete $artist->{dateCreated};
            delete $artist->{artUrl};
            delete $artist->{musicToken};
            my $artistName = delete $artist->{artistName};
            if ($self->format eq 'markdown') {
                say '-   ' . $artistName;
            } else {
                printf("ARTIST BOOKMARK: %s\n", $artistName);
            }
            if (scalar keys %$artist) {
                if ($self->format eq 'markdown') {
                    say '    -   unprocessed data: ', join(', ', sort keys %$artist);
                } else {
                    print $self->indent($self->json->encode($artist));
                }
            }
        }
        say '';
    }
    my $songs = delete $data->{songs};
    if (scalar @$songs) {
        if ($self->format eq 'markdown') {
            say "# Song Bookmarks";
            say '';
        }
        foreach my $song (@$songs) {
            delete $song->{musicToken};
            delete $song->{sampleUrl};
            delete $song->{dateCreated};
            delete $song->{bookmarkToken};
            delete $song->{sampleGain};
            delete $song->{artUrl};
            my $songName = delete $song->{songName};
            my $artistName = delete $song->{artistName};
            my $albumName = delete $song->{albumName};
            my $line = $artistName . ' -- ' . $songName;
            $line .= ' -- from: ' . $albumName if defined $albumName;
            if ($self->format eq 'markdown') {
                say '-   ' . $line;
            } else {
                printf("SONG BOOKMARK: %s\n", $line);
            }
            if (scalar keys %$song) {
                if ($self->format eq 'markdown') {
                    say '    -   unprocessed data: ', join(', ', sort keys %$song);
                } else {
                    say '    /* unprocessed */';
                    print $self->indent($self->json->encode($song));
                }
            }
        }
        say '';
    }
    if (scalar keys %$data) {
        if ($self->format eq 'markdown') {
            say 'unprocessed bookmark data: ', join(', ', sort keys %$data);
        } else {
            say 'unprocessed bookmark data:';
            print $self->indent($self->json->encode($data));
        }
        say '';
    }
}

sub listStations {
    my ($self) = @_;
    my $data = $self->readFile("stations.json");
    delete $data->{checksum};
    my $stations = delete $data->{stations};
    return if !scalar @$stations;

    if ($self->format eq 'markdown') {
        say "# Stations";
        say '';
    }

    foreach my $station (@$stations) {
        my $station = dclone($station);
        delete $station->{allowRename};
        delete $station->{dateCreated};
        delete $station->{stationSharingUrl};
        delete $station->{stationId};
        delete $station->{allowDelete};
        delete $station->{allowEditDescription};
        delete $station->{stationDetailUrl};
        delete $station->{allowAddMusic};
        delete $station->{isShared};
        delete $station->{processSkips};
        my $isThumbprint       = delete $station->{isThumbprint};
        my $thumbCount         = delete $station->{thumbCount};
        my $isQuickMix         = delete $station->{isQuickMix};
        my $token              = delete $station->{stationToken};
        my $isGenreStation     = delete $station->{isGenreStation};
        my $stationName        = delete $station->{stationName};
        my $genre              = delete $station->{genre};
        my $quickMixStationIds = delete $station->{quickMixStationIds};

        my $line = $stationName;
        $line .= ' [Genre Station]'    if $isGenreStation;
        $line .= ' [QuickMix]'         if $isQuickMix && $stationName ne 'QuickMix';
        $line .= ' [Thumbprint Radio]' if $isThumbprint && $stationName ne 'Thumbprint Radio';
        $line .= sprintf(' [%s thumbs]', $thumbCount) if defined $thumbCount;

        if ($self->format eq 'markdown') {
            say '-   ' . $line;
        } else {
            printf("STATION: %s\n", $line);
        }

        if (scalar keys %$station) {
            if ($self->format eq 'markdown') {
                say '    -   unprocessed data: ', join(', ', sort keys %$station);
            } else {
                say '    /* unprocessed */';
                print $self->indent($self->json->encode($station));
            }
        }
    }
    say '';

    if (scalar keys %$data) {
        if ($self->format eq 'markdown') {
            say 'unprocessed station list data: ', join(', ', sort keys %$data);
        } else {
            say 'unprocessed station list data:';
            print $self->indent($self->json->encode($data));
        }
        say '';
    }

    foreach my $station (@$stations) {
        $self->listStationData($station);
    }
}

sub listStationData {
    my ($self, $station) = @_;

    my $token = $station->{stationToken};
    my $name  = $station->{stationName};
    my $nameEscaped = uri_escape_utf8($name, UNSAFE);
    my $data = $self->readFile("stations/$nameEscaped.json");

    if ($self->format eq 'markdown') {
        say '## ' . $name;
        say '';
    }

    delete $data->{isShared};
    delete $data->{stationId};
    delete $data->{isQuickMix};
    delete $data->{stationToken};
    delete $data->{isGenreStation};
    delete $data->{stationSharingUrl};
    delete $data->{allowEditDescription};
    delete $data->{allowAddMusic};
    delete $data->{dateCreated};
    delete $data->{allowDelete};
    delete $data->{allowRename};
    delete $data->{artUrl};
    delete $data->{stationDetailUrl};
    my $stationName = delete $data->{stationName};
    delete $data->{processSkips};
    delete $data->{isThumbprint};
    delete $data->{thumbCount};
    delete $data->{quickMixStationIds};

    my $genre    = delete $data->{genre};
    my $feedback = delete $data->{feedback};
    my $music    = delete $data->{music};

    if ($feedback) {
        my $totalThumbsUp = delete $feedback->{totalThumbsUp};
        my $totalThumbsDown = delete $feedback->{totalThumbsDown};
        my $thumbsUp = delete $feedback->{thumbsUp};
        my $thumbsDown = delete $feedback->{thumbsDown};
        if (scalar @$thumbsUp || scalar @$thumbsDown) {
            if ($self->format eq 'markdown') {
                say '### Feedback';
                say '';
            }
            foreach my $thumb (@$thumbsUp, @$thumbsDown) {
                delete $thumb->{dateCreated};
                delete $thumb->{feedbackId};
                delete $thumb->{songIdentity};
                delete $thumb->{musicToken};
                delete $thumb->{pandoraId};
                delete $thumb->{albumArtUrl};
                my $isPositive  = delete $thumb->{isPositive};
                my $pandoraType = delete $thumb->{pandoraType};
                my $songName    = delete $thumb->{songName};
                my $artistName  = delete $thumb->{artistName};
                if ($pandoraType eq 'TR') {
                    my $line = '';
                    $line .= ':-) ' if $isPositive;
                    $line .= ':-( ' if !$isPositive;
                    $line .= $artistName . ' -- ' . $songName;
                    if ($self->format eq 'markdown') {
                        say '-   ', $line;
                    } else {
                        printf("STATION %s FEEDBACK: %s\n", $stationName, $line);
                    }
                } else {
                    say '-   FEEDBACK TYPE: ' . $pandoraType;
                }
                if (scalar keys %$thumb) {
                    if ($self->format eq 'markdown') {
                        say '    -   unprocessed data: ', join(', ', sort keys %$thumb);
                    } else {
                        say '    /* unprocessed */';
                        print $self->indent($self->json->encode($thumb));
                    }
                    say '';
                }
            }
            say '';
        }
        if (scalar keys %$feedback) {
            if ($self->format eq 'markdown') {
                say 'unprocessed station feedback data: ', join(', ', sort keys %$feedback);
            } else {
                say 'unprocessed station feedback data:';
                print $self->indent($self->json->encode($feedback));
            }
            say '';
        }
    }

    if ($music) {
        my $artists = delete $music->{artists};
        my $songs   = delete $music->{songs};
        my $genres  = delete $music->{genres};
        if (scalar @$artists) {
            if ($self->format eq 'markdown') {
                say '### Artists';
                say '';
            }
            foreach my $artist (@$artists) {
                my $artistName = delete $artist->{artistName};
                my $pandoraType = delete $artist->{pandoraType};
                delete @$artist{qw(artUrl icon musicToken pandoraId seedId)};
                my $line = $artistName;
                $line .= sprintf(' [%s]', $pandoraType) if defined $pandoraType && $pandoraType ne 'AR';
                if ($self->format eq 'markdown') {
                    say '-   ' . $line;
                } else {
                    printf("STATION %s ARTIST SEED: %s\n", $stationName, $line);
                }

                if (scalar keys %$artist) {
                    if ($self->format eq 'markdown') {
                        say '    -   unprocessed data: ', join(', ', sort keys %$artist);
                    } else {
                        say '    /* unprocessed */';
                        print $self->indent($self->json->encode($artist));
                    }
                }
            }
            say '';
        }

        if (scalar @$songs) {
            if ($self->format eq 'markdown') {
                say '### Songs';
                say '';
            }
            foreach my $song (@$songs) {
                delete @$song{qw(artUrl musicToken pandoraId seedId)};
                my $artistName = delete $song->{artistName};
                my $songName = delete $song->{songName};
                my $pandoraType = delete $song->{pandoraType};
                my $line = $artistName . ' -- ' . $songName;
                $line .= sprintf(' [%s]', $pandoraType) if defined $pandoraType && $pandoraType ne 'TR';
                if ($self->format eq 'markdown') {
                    say '-   ' . $line;
                } else {
                    printf("STATION %s SONG SEED: %s\n", $stationName, $line);
                }
                if (scalar keys %$song) {
                    if ($self->format eq 'markdown') {
                        say '    -   unprocessed data: ', join(', ', sort keys %$song);
                    } else {
                        say '    /* unprocessed */';
                        print $self->indent($self->json->encode($song));
                    }
                }
            }
            say '';
        }

        if (scalar @$genres) {
            if ($self->format eq 'markdown') {
                say '### Genres';
                say '';
            }
            foreach my $genre (@$genres) {
                delete $genre->{musicToken};
                delete $genre->{seedId};
                my $genreName = delete $genre->{genreName};
                if ($self->format eq 'markdown') {
                    say '-   ' . $genreName;
                } else {
                    printf("STATION %s GENRE SEED: %s\n", $stationName, $genreName);
                }
                if (scalar keys %$genre) {
                    if ($self->format eq 'markdown') {
                        say '    -   unprocessed data: ', join(', ', sort keys %$genre);
                    } else {
                        say '    /* unprocessed */';
                        print $self->indent($self->json->encode($genre));
                    }
                }
            }
            say '';
        }
        if (scalar keys %$music) {
            if ($self->format eq 'markdown') {
                say 'unprocessed station music data: ', join(', ', sort keys %$music);
            } else {
                say 'unprocessed station music data:';
                print $self->indent($self->json->encode($music));
            }
            say '';
        }
    }

    if ($genre) {
        if (ref $genre eq 'ARRAY') {
            if (scalar @$genre) {
                if ($self->format eq 'markdown') {
                    say 'genre tags: ', join('; ', @$genre);
                    say '';
                } else {
                    printf("STATION %s PRE-SELECTED GENRE: %s\n", $stationName, $_) foreach @$genre;
                    say '';
                }
            }
        } elsif ($genre) {
            say 'genre tags: ', $self->json->encode($genre);
            say '';
        }
    }

    if (scalar keys %$data) {
        if ($self->format eq 'markdown') {
            say 'unprocessed station data: ', join(', ', sort keys %$data);
        } else {
            say 'unprocessed station data:';
            print $self->indent($self->json->encode($data));
        }
        say '';
    }
}

sub readFile {
    my ($self, $filename) = @_;
    $filename = rel2abs($filename, $self->dataDir);
    my $fh;
    open($fh, '<', $filename)        or die("open $filename: $!\n");
    binmode($fh, ':utf8')            or die("binmode $filename: $!\n");
    local $/ = undef;
    my $contents = <$fh>;
    close($fh)                       or die("close $filename: $!\n");
    my $result = $self->json->decode($contents);
    return $result;
}

sub indent {
    my ($self, $text, $spaces) = @_;
    $spaces //= 4;
    my $space = ' ' x $spaces;
    $text =~ s{\R}{\n}gx;
    $text =~ s{^}{$spaces}gemx;
    return $text;
}

1;
