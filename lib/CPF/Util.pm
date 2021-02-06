package CPF::Util;

use strict;
use warnings;

my @specs = qw(
./Nouns/DispatchList.xsd
./Nouns/MatchDocument.xsd
./Nouns/EmployeeWorkTime.xsd
./Nouns/Payable.xsd
./Nouns/DebitTransferIST.xsd
./Nouns/ProductionOrder.xsd
./Nouns/InvoiceLedgerEntry.xsd
./Nouns/EngineeringChangeOrder.xsd
./Nouns/DebitTransfer.xsd
./Nouns/PurchaseOrder.xsd
./Nouns/PlanningSchedule.xsd
./Nouns/InventoryCount.xsd
./Nouns/CreditTransferIST.xsd
./Nouns/EmployeeWorkSchedule.xsd
./Nouns/RFQ.xsd
./Nouns/Personnel.xsd
./Nouns/Catalog.xsd
./Nouns/Quote.xsd
./Nouns/Routing.xsd
./Nouns/UOMGroup.xsd
./Nouns/InspectDelivery.xsd
./Nouns/ChartOfAccounts.xsd
./Nouns/WIPStatus.xsd
./Nouns/PriceList.xsd
./Nouns/Operation.xsd
./Nouns/CurrencyExchangeRate.xsd
./Nouns/BudgetLedger.xsd
./Nouns/Opportunity.xsd
./Nouns/MergeWIP.xsd
./Nouns/CarrierRoute.xsd
./Nouns/RequireProduct.xsd
./Nouns/CustomerPartyMaster.xsd
./Nouns/EngineeringWorkDocument.xsd
./Nouns/InventoryBalance.xsd
./Nouns/SequenceSchedule.xsd
./Nouns/PaymentStatus.xsd
./Nouns/SalesLead.xsd
./Nouns/AllocateResource.xsd
./Nouns/InventoryConsumption.xsd
./Nouns/ProjectAccounting.xsd
./Nouns/PaymentStatusIST.xsd
./Nouns/CreditTransfer.xsd
./Nouns/ActualLedger.xsd
./Nouns/BOM.xsd
./Nouns/OnlineSession.xsd
./Nouns/SalesOrder.xsd
./Nouns/RecoverWIP.xsd
./Nouns/ConfirmWIP.xsd
./Nouns/ProductAvailability.xsd
./Nouns/MoveWIP.xsd
./Nouns/ShipmentSchedule.xsd
./Nouns/CreditStatus.xsd
./Nouns/Receivable.xsd
./Nouns/LocationService.xsd
./Nouns/PartyMaster.xsd
./Nouns/MoveInventory.xsd
./Nouns/PickList.xsd
./Nouns/Shipment.xsd
./Nouns/ReceiveDelivery.xsd
./Nouns/ShipmentUnit.xsd
./Nouns/ReceiveItem.xsd
./Nouns/OnlineOrder.xsd
./Nouns/BOD.xsd
./Nouns/Credit.xsd
./Nouns/RiskControlLibrary.xsd
./Nouns/SplitWIP.xsd
./Nouns/Invoice.xsd
./Nouns/Requisition.xsd
./Nouns/ItemMaster.xsd
./Nouns/Field.xsd
./Nouns/Location.xsd
./Nouns/CostingActivity.xsd
./Nouns/JournalEntry.xsd
./Nouns/MaintenanceOrder.xsd
./Nouns/SupplierPartyMaster.xsd
./Nouns/ProjectMaster.xsd
./Nouns/IssueInventory.xsd
./Components/Financial/Components.xsd
./Components/Financial/iso20022/$pain.002.001.01.xsd
./Components/Financial/iso20022/$pain.001.001.01.xsd
./Components/Operational/LogisticsComponents.xsd
./Components/Operational/OrderManagementComponents.xsd
./Components/Operational/ManufacturingComponents.xsd
./Components/Operational/CRMComponents.xsd
./Components/Common/Components.xsd
./Components/Common/Fields.xsd
./Components/Common/Meta.xsd
./Components/Common/CodeLists.xsd
./Components/CoreComponents/ReusableAggregateBusinessInformationEntity.xsd
./Components/CoreComponents/CodeList_MIMEMediaTypeCode_IANA_7_04.xsd
./Components/CoreComponents/CodeList_UnitCode_UNECE_7_04.xsd
./Components/CoreComponents/ReusableAggregateCoreComponent.xsd
./Components/CoreComponents/UnqualifiedDataTypes.xsd
./Components/CoreComponents/CodeList_LanguageCode_ISO_7_04.xsd
./Components/CoreComponents/CoreComponentTypes.xsd
./Components/CoreComponents/CodeList_CurrencyCode_ISO_7_04.xsd
./Components/CoreComponents/QualifiedDataTypes.xsd
./OAGIS-9_0-Resources.xsd
);
@specs = map { "OAGIS/9.0/Resources/".$_ } @specs;

sub import_definitions
{   my ($class, $schema) = @_;
    $schema->importDefinitions(\@specs);
}

sub standard_p2p_elements
{   my ($class, $schema, $doc) = @_;

    my $p2p_appl = $doc->createElement('oagis:UserArea');
    my $rec = $schema->writer('p2p:Receiver')->($doc, 'CPF');
    $p2p_appl->appendChild($rec);
    my $ind = $schema->writer('p2p:PriorityIndicator')->($doc, '01');
    $p2p_appl->appendChild($ind);
    my $int = $schema->writer('p2p:InterfaceVersionID')->($doc, 'CPFv1');
    $p2p_appl->appendChild($int);
    $p2p_appl;
}

sub header
{ '<?xml version="1.0" encoding="UTF-8" ?>' }

sub parse
{   my ($class, $data) = @_;

    my $header = $data->{'oagis:DataArea'}->{'oagis:PurchaseOrder'}->{'oagis:PurchaseOrderHeader'};

    my $parsed;

    $parsed->{po_number}       = $header->{'oagis:DocumentID'}->{'oagis:ID'};
    $parsed->{revision_number} = $header->{'oagis:DocumentID'}->{'oagis:RevisionID'};
    $parsed->{release_number}  = $header->{'oagis:ReleaseNumber'};

    my $v   = $header->{'oagis:ContractReference'}->{'oagis:DocumentID'}->{'oagis:ID'};
    my $ref = ref $v && !values %$v ? undef : $v;
    $parsed->{contract_reference} = $ref;

    $parsed->{payment_term} = $header->{'oagis:PaymentTerm'}->{'oagis:Description'};
    $parsed->{buyer_name}   = $header->{'oagis:BuyerParty'}->{'oagis:Contact'}->{'oagis:Name'};

    $v = $header->{'oagis:Note'} if $header->{'oagis:Note'};
    my $notes = ref $v && !values %$v ? undef : $v;
    $parsed->{notes_to_supplier} = $notes;

    $v = $header->{'oagis:Description'} if $header->{'oagis:Description'};
    $parsed->{text_attachment}  = ref $v && !values %$v ? undef : $v;
    $parsed->{release_number}   = $header->{'oagis:ReleaseNumber'};
    $parsed->{buyer_vat_number} = $header->{'oagis:BuyerParty'}->{'oagis:PartyIDs'} && $header->{'oagis:BuyerParty'}->{'oagis:PartyIDs'}->{'TaxID'};

    $parsed->{lines} = [];

    my $lines = $data->{'oagis:DataArea'}->{'oagis:PurchaseOrder'}->{'oagis:PurchaseOrderLine'};
    my @lines = ref $lines eq 'ARRAY' ? @{$lines} : ($lines);

    foreach my $line (@lines)
    {
        my $supplier_id = $line->{'oagis:Item'}->{'oagis:SupplierItemID'}->{'oagis:ID'};
        my $mod_id      = $line->{'oagis:Item'}->{'oagis:ItemID'}->{'oagis:ID'};
        my $attach      = $line->{'oagis:Description'};
        my $freetext    = $line->{'oagis:Note'};
        my $notes       = $line->{'oagis:DocumentReference'}->{'oagis:Note'};

        my $l = {
            line_number => $line->{'oagis:LineNumber'},
            description => $line->{'oagis:Item'}->{'oagis:Description'},
            supplier_id => ref $supplier_id && !values %$supplier_id ? undef : $supplier_id,
            mod_id      => ref $mod_id && !values %$mod_id ? undef : $mod_id,
            attachment  => ref $attach && !values %$attach ? undef : $attach,
            line_status => $line->{'oagis:Status'}->{'oagis:Reason'},
            free_text   => ref $freetext ? $freetext : $freetext ? [$freetext] : undef,
            notes       => ref $notes && !values %$notes ? undef : $notes,
            amount      => {
                total => $line->{'oagis:ExtendedAmount'}->{content},
            },
            price => {
                amount   => $line->{'oagis:UnitPrice'}->{'oagis:Amount'}->{content},
                quantity => $line->{'oagis:UnitPrice'}->{'oagis:PerQuantity'}->{content},
                unit     => $line->{'oagis:UnitPrice'}->{'oagis:PerQuantity'}->{unitCode},
            },
        };
        $l->{amount}->{received} = {
            qty  => $line->{'oagis:OpenQuantity'}->{content},
            unit => $line->{'oagis:OpenQuantity'}->{'unitCode'},
        } if $line->{'oagis:OpenQuantity'};
        $l->{amount}->{open} = {
            qty  => $line->{'oagis:ReceivedQuantity'}->{content},
            unit => $line->{'oagis:ReceivedQuantity'}->{'unitCode'},
        } if $line->{'oagis:ReceivedQuantity'};
        $l->{amount}->{ordered} = {
            qty  => $line->{'oagis:Quantity'}->{content},
            unit => $line->{'oagis:Quantity'}->{unitCode},
        } if $line->{'oagis:Quantity'};
        push @{$parsed->{lines}}, $l;
    };
    $parsed;
}

1;

