using Microsoft.EntityFrameworkCore.Migrations;

public partial class ExpandProductIdentity : Migration
{
    protected override void Up(MigrationBuilder migrationBuilder)
    {
        migrationBuilder.AddColumn<Guid>(
            name: "id",
            table: "products",
            type: "uuid",
            nullable: false,
            defaultValueSql: "gen_random_uuid()");

        migrationBuilder.AddColumn<Guid>(
            name: "product_id",
            table: "tickets",
            type: "uuid",
            nullable: true);

        migrationBuilder.CreateIndex(
            name: "IX_products_id",
            table: "products",
            column: "id",
            unique: true);

        migrationBuilder.AddForeignKey(
            name: "tickets_product_id_fk",
            table: "tickets",
            column: "product_id",
            principalTable: "products",
            principalColumn: "id");
    }

    protected override void Down(MigrationBuilder migrationBuilder)
    {
        migrationBuilder.DropForeignKey(
            name: "tickets_product_id_fk",
            table: "tickets");

        migrationBuilder.DropColumn(name: "product_id", table: "tickets");
        migrationBuilder.DropColumn(name: "id", table: "products");
    }
}