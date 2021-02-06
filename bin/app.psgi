#!/usr/bin/env perl

use strict;
use warnings;
use FindBin;
use lib "$FindBin::Bin/../lib";

use CPF;

use Plack::Builder;

builder {
    CPF->to_app;
};
