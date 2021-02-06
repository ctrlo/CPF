use utf8;
package CPF::Schema::Result::Invoice;

# Created by DBIx::Class::Schema::Loader
# DO NOT MODIFY THE FIRST PART OF THIS FILE

=head1 NAME

CPF::Schema::Result::Invoice

=cut

use strict;
use warnings;

use base 'DBIx::Class::Core';

=head1 COMPONENTS LOADED

=over 4

=item * L<DBIx::Class::InflateColumn::DateTime>

=back

=cut

__PACKAGE__->load_components("InflateColumn::DateTime");

=head1 TABLE: C<invoice>

=cut

__PACKAGE__->table("invoice");

=head1 ACCESSORS

=head2 id

  data_type: 'integer'
  is_auto_increment: 1
  is_nullable: 0

=head2 description

  data_type: 'text'
  is_nullable: 1

=head2 customer_id

  data_type: 'integer'
  is_foreign_key: 1
  is_nullable: 1

=head2 date

  data_type: 'date'
  datetime_undef_if_invalid: 1
  is_nullable: 1

=cut

__PACKAGE__->add_columns(
  "id",
  { data_type => "integer", is_auto_increment => 1, is_nullable => 0 },
  "description",
  { data_type => "text", is_nullable => 1 },
  "customer_id",
  { data_type => "integer", is_foreign_key => 1, is_nullable => 1 },
  "date",
  { data_type => "date", datetime_undef_if_invalid => 1, is_nullable => 1 },
);

=head1 PRIMARY KEY

=over 4

=item * L</id>

=back

=cut

__PACKAGE__->set_primary_key("id");

=head1 RELATIONS

=head2 customer

Type: belongs_to

Related object: L<CPF::Schema::Result::Customer>

=cut

__PACKAGE__->belongs_to(
  "customer",
  "CPF::Schema::Result::Customer",
  { id => "customer_id" },
  {
    is_deferrable => 1,
    join_type     => "LEFT",
    on_delete     => "RESTRICT",
    on_update     => "RESTRICT",
  },
);

=head2 invoice_items

Type: has_many

Related object: L<CPF::Schema::Result::InvoiceItem>

=cut

__PACKAGE__->has_many(
  "invoice_items",
  "CPF::Schema::Result::InvoiceItem",
  { "foreign.invoice_id" => "self.id" },
  { cascade_copy => 0, cascade_delete => 0 },
);


# Created by DBIx::Class::Schema::Loader v0.07042 @ 2016-05-22 17:17:09
# DO NOT MODIFY THIS OR ANYTHING ABOVE! md5sum:NZ7xTRzpJ08uudmTvoWVTg


# You can replace this text with custom code or comments, and it will be preserved on regeneration
1;
