use utf8;
package CPF::Schema::Result::InvoiceItem;

# Created by DBIx::Class::Schema::Loader
# DO NOT MODIFY THE FIRST PART OF THIS FILE

=head1 NAME

CPF::Schema::Result::InvoiceItem

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

=head1 TABLE: C<invoice_item>

=cut

__PACKAGE__->table("invoice_item");

=head1 ACCESSORS

=head2 id

  data_type: 'integer'
  is_auto_increment: 1
  is_nullable: 0

=head2 invoice_id

  data_type: 'integer'
  is_foreign_key: 1
  is_nullable: 1

=head2 item_id

  data_type: 'integer'
  is_foreign_key: 1
  is_nullable: 1

=head2 quantity

  data_type: 'integer'
  is_nullable: 1

=cut

__PACKAGE__->add_columns(
  "id",
  { data_type => "integer", is_auto_increment => 1, is_nullable => 0 },
  "invoice_id",
  { data_type => "integer", is_foreign_key => 1, is_nullable => 1 },
  "item_id",
  { data_type => "integer", is_foreign_key => 1, is_nullable => 1 },
  "quantity",
  { data_type => "integer", is_nullable => 1 },
);

=head1 PRIMARY KEY

=over 4

=item * L</id>

=back

=cut

__PACKAGE__->set_primary_key("id");

=head1 RELATIONS

=head2 invoice

Type: belongs_to

Related object: L<CPF::Schema::Result::Invoice>

=cut

__PACKAGE__->belongs_to(
  "invoice",
  "CPF::Schema::Result::Invoice",
  { id => "invoice_id" },
  {
    is_deferrable => 1,
    join_type     => "LEFT",
    on_delete     => "RESTRICT",
    on_update     => "RESTRICT",
  },
);

=head2 item

Type: belongs_to

Related object: L<CPF::Schema::Result::Item>

=cut

__PACKAGE__->belongs_to(
  "item",
  "CPF::Schema::Result::Item",
  { id => "item_id" },
  {
    is_deferrable => 1,
    join_type     => "LEFT",
    on_delete     => "RESTRICT",
    on_update     => "RESTRICT",
  },
);


# Created by DBIx::Class::Schema::Loader v0.07042 @ 2016-05-22 17:17:09
# DO NOT MODIFY THIS OR ANYTHING ABOVE! md5sum:PDKOxi/j0E6oOHDBp8KNew


# You can replace this text with custom code or comments, and it will be preserved on regeneration
1;
