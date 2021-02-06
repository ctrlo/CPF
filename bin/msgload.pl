#!/usr/bin/perl

use FindBin;
use lib "$FindBin::Bin/../lib";

use DateTime;
use Getopt::Long;
use CPF::Util;
use XML::Compile::Schema;
use XML::Compile::Util  'pack_type';
use XML::Compile::Cache;
use XML::LibXML::Simple;

use Dancer2;
use Dancer2::Plugin::DBIC;

binmode(STDOUT, ":utf8");

my ($type, $invoice_number, $invoice_description, $invoice_date);

GetOptions (
    'type=s'                => \$type,
    'invoice-number=s'      => \$invoice_number,
    'invoice-description=s' => \$invoice_description,
    'invoice-date=s'        => \$invoice_date,
) or exit;

if ($type)
{
    $type =~ /^(AcknowledgePurchaseOrder|Invoice)$/
        or die "Message type must be AcknowledgePurchaseOrder or Invoice";
}
else {
    $type = ''; # Prevent uninit warnings
    say STDOUT "--type not specified, will only print contents";
}

if ($type eq 'Invoice')
{
    $invoice_number
        or die "Specify invoice number with --invoice-number";
    $invoice_description
        or die "Specify invoice description with --invoice-description";
}

# Only create message in database if type specified
my $msg = $type && schema->resultset('Cpfmsg')->create({
    type    => $type,
    deleted => 1, # start deleted so not picked up
});

my $xsd = $type eq 'Invoice' ? 'OAGIS/9.0/BODs/Developer/ProcessInvoice.xsd' : 'OAGIS/9.0/BODs/Developer/AcknowledgePurchaseOrder.xsd';
my $schema = XML::Compile::Cache->new([$xsd, 'P2P/decsP2PSchema.xsd']
    , prefixes => {
        p2p   => "http://www.d2btrade.com/p2p/9",
        oagis => 'http://www.openapplications.org/oagis/9',
    },
    allow_undeclared => 1
);

CPF::Util->import_definitions($schema);

my $data = XMLin('-');
my $parsed = CPF::Util->parse($data);
my $doc = XML::LibXML::Document->new('1.0', 'UTF-8');
my $p2p_appl = CPF::Util->standard_p2p_elements($schema, $doc);

say STDOUT "PO number $parsed->{po_number} from $parsed->{buyer_name} for contract $parsed->{contract_reference}";
say STDOUT "    Revision number: $parsed->{revision_number} (only items not already received will be invoiced)"
    if $parsed->{revision_number};
say STDOUT "    Notes: $parsed->{notes_to_supplier}"
    if $parsed->{notes_to_supplier};
say STDOUT "    Text attachment: $parsed->{text_attachment}"
    if $parsed->{text_attachment};
say STDOUT "Lines are:";
foreach (@{$parsed->{lines}})
{
    my $mod_id = $_->{mod_id};
    $mod_id ||= "[No MOD ID]";
    say STDOUT "$_->{line_number} ($_->{line_status}): "
        ."$mod_id (desc: $_->{description}) "
        ."price: $_->{price}->{amount} per $_->{price}->{quantity}$_->{price}->{unit}, "
        ."total: $_->{amount}->{total}";
    say STDOUT "    Ordered $_->{amount}->{ordered}->{qty}$_->{amount}->{ordered}->{unit}"
        if $_->{amount}->{ordered};
    say STDOUT "    Received $_->{amount}->{received}->{qty}$_->{amount}->{received}->{unit}"
        if $_->{amount}->{received};
    say STDOUT "    Open $_->{amount}->{open}->{qty}$_->{amount}->{open}->{unit}"
        if $_->{amount}->{open};
    say STDOUT "    Attachment: $_->{attachment}"
        if $_->{attachment};
    say STDOUT "    Notes: ".join(' ',@{$_->{free_text}})
        if $_->{free_text};
}

$type or exit;

my $xml;

if ($type eq 'AcknowledgePurchaseOrder')
{
    my $response = {
        po_number         => $parsed->{po_number},
        po_revision       => $parsed->{revision_number},
        po_release_number => $parsed->{release_number},
        contract_id       => $parsed->{contract_reference},
        action            => 'Accepted', # Accepted / Rejected / Modified
        note              => 'Accepted OK',
        bodid             => config->{cpf}->{prefix}.$msg->id,
    };

    my %perl = (
        ApplicationArea => {
            Sender => {
                LogicalID => config->{cpf}->{logical_id}, # My ID
    #            ComponentID => "Additional Reference", # Reserved for future use
                ConfirmationCode => "Never", # Always "never"
                AuthorizationID => "00", # Always "00"
            },
            CreationDateTime => DateTime->now, # Date PO acknowledgement is created by Trading Partner
            BODID => $response->{bodid}, # XXX Has to be unique for each message sent
            UserArea => $p2p_appl,
        },
        DataArea => {
            Acknowledge => {
                ResponseCriteria => [ {
                    ResponseExpression => {
                        actionCode => $response->{action}, # PO acceptance Code “Accepted”, “Rejected” or “Modified”
                        _ => "//oagis:AcknowledgePurchaseOrder/oagis:DataArea/oagis:PurchaseOrder ",
                    },
                } ],
            },
            PurchaseOrder => {
                PurchaseOrderHeader => {
                    DocumentID => {
                        ID => $response->{po_number}, # XXX CPF Purchase Order number as sent on original ProcessPurchaseOrder message
                        RevisionID => $response->{po_revision}, # XXX Revision Number as sent on original ProcessPurchaseOrder message.
                    },
                    Note => $response->{note}, # Notes / Comments from TP at header level, e.g. rejection reason
                    SupplierParty => {
                        Name => config->{cpf}->{supplier}->{name}, # Supplier name
                        Location => {
                            Address => { # Supplier's remittance address
                                AddressLine => [
                                    {
                                        sequence => 1,
                                        _ => config->{cpf}->{supplier}->{address1},
                                    }, {
                                        sequence => 2,
                                        _ => config->{cpf}->{supplier}->{address2},
                                    }, {
                                        sequence => 6,
                                        _ => "United Kingdom",
                                    },
                                ],
                                PostalCode => config->{cpf}->{supplier}->{postcode},
                            },
                        },
                        Contact => { # Accounts contact details
                            Name => config->{cpf}->{contact}->{name},
                            Communication => config->{cpf}->{contact}->{communication},
                        },
                    },
                    ContractReference => {
                        DocumentID => {
                            ID => $response->{contract_id}, # XXX MoD Contract Number as sent on original ProcessPurchaseOrder message
                        },
                    },
                },
            },
        },
        releaseID => "9.0",
    );

    # Only populated for Blanket Purchase Agreements.
    $perl{DataArea}->{PurchaseOrder}->{PurchaseOrderHeader}->{ReleaseNumber}
        = $response->{po_release_number}
        if defined $response->{po_release_number};

    my $gns = 'http://www.openapplications.org/oagis/9';
    my $wr  = $schema->compile(WRITER => pack_type($gns, 'AcknowledgePurchaseOrder'));
    $xml = $wr->($doc, \%perl);
}
elsif ($type eq 'Invoice')
{

    my $response = {
        # previous_invoice_date => '2015-03-05T15:36:09', # Needs to be previous inv date for credit
        # previous_invoice_number => '000014', # Previous invoice number for refund
        type                => 'STANDARD', # STANDARD or CREDIT
        invoice_number      => $invoice_number,
        invoice_description => $invoice_description,
        payment_term        => $parsed->{payment_term},
        po_number           => $parsed->{po_number},
        po_release_number   => $parsed->{release_number},
        buyer               => $parsed->{buyer_name},
        lines               => $parsed->{lines},
        bodid               => config->{cpf}->{prefix}.$msg->id,
        total               => 0, # Start on zero, then increment with line prices
    };
    $response->{invoice_date} = $parsed->{previous_invoice_date} || $invoice_date || DateTime->now;

    my @lines; my $count;

    foreach my $line (@{$response->{lines}})
    {
        my $quantity   = $line->{amount}->{ordered}->{qty};
        $quantity      = $quantity - $line->{amount}->{received}->{qty}
            if $line->{amount}->{received}->{qty};
        my $price_ea   = $line->{price}->{amount};
        my $line_total = $quantity * $price_ea;
        $response->{total} += $line_total;
        push @lines, {
            LineNumber => ++$count,  # Sequential line number
            # Note => "Notes go here", # XXX Any notes
            Item => {
                Description => $line->{description}, # Product description
            },
            Quantity => {
                unitCode => "EA", # XXX Quantity invoiced
                _ => $quantity,
            },
            UnitPrice => {
                Amount => {
                    currencyID => "GBP",
                    _ => $price_ea, # XXX Unit price of item
                },
                PerQuantity => {
                    unitCode => "EA", # XXX Unit of measure
                    _ => "1",
                },
            },
            PurchaseOrderReference => {
                ReleaseNumber => $response->{po_release_number}, # XXX PO release number from PO
                LineNumber => $line->{line_number}, # XXX PO Line No / Shipment No as sent on PO
            },
            ExtendedAmount => { # XXX Line amount total excluding taxes
                currencyID => "GBP",
                _ => $line_total,
            },
            Tax => {
                type => "ValueAddedTax",
                ID => "F1", # Line tax code XXX what is this?
                Calculation => {
                    RateNumeric => "20.00",
                },
            },
        };
    }
    say STDOUT "Invoicing total of $response->{total} for ".@lines." lines";

    my $vat = sprintf("%.2f", $response->{total} * 0.2);

    my %perl = (
        ApplicationArea => {
            Sender => {
                LogicalID => config->{cpf}->{logical_id}, # My ID
    #            ComponentID => "Additional Reference", # Reserved for future use
                ConfirmationCode => "Never", # Always "never"
                AuthorizationID => "00", # Always "00"
            },
            CreationDateTime => DateTime->now,
            BODID => $response->{bodid}, # XXX Has to be unique for each message sent
            UserArea => $p2p_appl,
        },
        DataArea => {
            Process => {
                ActionCriteria =>
                [
                    {
                        ActionExpression =>
                        [
                            {
                                actionCode => "Add", # Always "add"?
                            },
                        ],
                    }
                ],
                acknowledgeCode => "Never", # Always "never"?
            },
            Invoice =>
            [
                {
                    type => $response->{type}, # XXX Invoice type, STANDARD or CREDIT
                    InvoiceHeader => {
                        DocumentID => {
                            ID => $response->{invoice_number}, # XXX My invoice number, max 14 chars
                        },
                        DocumentDateTime => $response->{invoice_date}, # Date invoice raised
                        Description => $response->{invoice_description}, # XXX Invoice description
                        DocumentReference => [ {
                            type => "TaxInvoiceNumber",
                            DocumentID => {
                                ID => $response->{invoice_number}, # XXX My invoice number
                            },
                            DocumentDateTime => $response->{invoice_date}, # XXX Tax point date
                        } ],
                        ExtendedAmount => { # Total amount of invoice exluding VAT
                            currencyID => "GBP", # Reference currency
                            _ => $response->{total}, # XXX
                        },
                        TotalAmount => { # Total amount of invoice including VAT
                            currencyID => "GBP", # Reference currency
                            _ => sprintf("%.2f", $response->{total} + $vat), # XXX
                        },
                        CustomerParty => {
                            PartyIDs => {
                                ID => $response->{buyer}, # XXX Buyer Code as found on the Purchase Order
                                TaxID => "GB 888 8050 68", # XXX MOD VAT Registration number (poss on PO)
                            },
                        },
                        RemitToParty => {
                            PartyIDs => {
                                ID => config->{cpf}->{gax_code}, # My GAX code
                                TaxID => config->{cpf}->{supplier}->{vat},
                            },
                            Name => config->{cpf}->{supplier}->{name}, # Supplier name
                            Location => {
                                Address => { # Supplier's remittance address
                                    AddressLine => [
                                        {
                                            sequence => 1,
                                            _ => config->{cpf}->{supplier}->{address1},
                                        },
                                        {
                                            sequence => 2,
                                            _ => config->{cpf}->{supplier}->{address2},
                                        },
                                        {
                                            sequence => 6,
                                            _ => "United Kingdom",
                                        },
                                    ],
                                    PostalCode => config->{cpf}->{supplier}->{postcode},
                                },
                            },
                            Contact => { # Accounts contact details
                                Name => config->{cpf}->{contact}->{name},
                                Communication => config->{cpf}->{contact}->{communication},
                            },
                        },
                        PurchaseOrderReference => {
                            DocumentID => {
                                ID => $response->{po_number}, # XXX MoD Original Purchase Order Number as sent on PO
                            },
                            ReleaseNumber => $response->{po_release_number}, # "21877", # XXX PO Release No as sent on the PO (may be null)
                        },
                        PaymentTerm => {
                            Term => {
                                Description => $response->{payment_term}, # XXX Payment term, as sent on PO
                            },
                        },
                        Tax => [
                            {
                                type => "VATRateSummary",
                                ID => "F1",
                                BasisAmount => {
                                    currencyID => "GBP",
                                    _ => $response->{total}, # XXX Taxable amount (at rate)
                                },
                                Calculation => {
                                    RateNumeric => "20.00", # VAT tax rate
                                },
                                Amount => {
                                    currencyID => "GBP",
                                    _ => $vat, # XXX Total amount of VAT
                                },
                            },
                            {
                                type => "TotalVAT", # XXX Total VAT amount in this currency
                                BasisAmount => {
                                    currencyID => "GBP", # Total taxable
                                    _ => $response->{total},
                                },
                                Amount => {
                                    currencyID => "GBP",
                                    _ => $vat, # VAT amount
                                },
                            },
                        ],
                    },
                    InvoiceLine => \@lines,
                }
            ],
        },
        releaseID => "9.0",
    );

    # Previous invoice number to reference for credit
    push @{$perl{DataArea}->{Invoice}->[0]->{InvoiceHeader}->{DocumentReference}},
    {
        type => "PreviousInvoiceNumber",
        DocumentID => {
            ID => $response->{previous_invoice_number}, # XXX My invoice number
        },
        DocumentDateTime => $response->{previous_invoice_date} # XXX Tax point date
    } if $response->{previous_invoice_number};

    my $gns = 'http://www.openapplications.org/oagis/9';
    my $wr  = $schema->compile(WRITER => pack_type($gns, 'ProcessInvoice'));
    $xml = $wr->($doc, \%perl);
}
else {
    die "Invalid type $type";
}

$msg->update({
    deleted => 0, # allow message to be read - comment out during testing
    content => CPF::Util->header.$xml->toString(1),
});

