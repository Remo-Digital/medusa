import { Migration } from "@medusajs/framework/mikro-orm/migrations";

export class Migration20261104153607 extends Migration {

  override async up(): Promise<void> {
    this.addSql(`alter table if exists "promotion_campaign_budget" alter column "raw_used" type jsonb using ("raw_used"::jsonb);`);
    this.addSql(`alter table if exists "promotion_campaign_budget" alter column "raw_used" set default '{"value":"0","precision":20}';`);

    this.addSql(`alter table if exists "promotion_campaign_budget_usage" alter column "raw_used" type jsonb using ("raw_used"::jsonb);`);
    this.addSql(`alter table if exists "promotion_campaign_budget_usage" alter column "raw_used" set default '{"value":"0","precision":20}';`);

    this.addSql(`alter table if exists "promotion_application_method" add column if not exists "min_quantity" integer null;`);
  }

  override async down(): Promise<void> {
    this.addSql(`alter table if exists "promotion_campaign_budget" alter column "raw_used" drop default;`);
    this.addSql(`alter table if exists "promotion_campaign_budget" alter column "raw_used" type jsonb using ("raw_used"::jsonb);`);

    this.addSql(`alter table if exists "promotion_campaign_budget_usage" alter column "raw_used" drop default;`);
    this.addSql(`alter table if exists "promotion_campaign_budget_usage" alter column "raw_used" type jsonb using ("raw_used"::jsonb);`);

    this.addSql(`alter table if exists "promotion_application_method" drop column if exists "min_quantity";`);
  }

}
