# Kort evidens: daglig captured revenue

Der blev testet fire løsninger:

- direkte SQL-query: [`base_revenue.sql`](../database/postgres/queries/base_revenue.sql)
- SQL-funktion: [`020_reporting_function.sql`](../database/postgres/migrations/020_reporting_function.sql)
- materialiseret view: [`022_daily_captured_revenue.sql`](../database/postgres/migrations/022_daily_captured_revenue.sql)
- trigger-summary: [`021_daily_revenue_trigger.sql`](../database/postgres/migrations/021_daily_revenue_trigger.sql)

Den direkte query og funktionen gav altid samme, aktuelle resultat.

Testene viste:

- Et nyt captured payment blev straks vist af queryen og funktionen.
- Det materialiserede view var først korrekt efter `REFRESH MATERIALIZED VIEW`.
- Et failed payment ændrede ikke revenue.
- Ved `Failed -> Captured` steg live-resultatet til `122 / 3`, men trigger-summary stod stadig på `36 / 1`.
- Ved `Captured -> Refunded` fjernede live-resultatet betalingen, men triggeren gjorde ikke.
- En dublet ekstern reference blev talt to gange, fordi der mangler en unik constraint på `external_payment_reference`.
- Efter sletning blev både view og trigger-summary forældede.

Formatet ovenfor er `beløb / antal payments` for `OP-METRO`.

Ved en captured insert indsættes paymenten, triggeren finder operatoren og opdaterer `daily_revenue_by_operator`. Payment og summary rulles tilbage sammen ved rollback. Viewet ændres ikke før refresh.

## Konklusion

Brug den direkte query eller SQL-funktionen som autoritativ rapport. Den er aktuel efter inserts, statusændringer og sletninger og har ingen ekstra kopi, der skal vedligeholdes.

Brug kun materialiseret view som en refreshbar cache, hvis hurtige læsninger er vigtige. Brug ikke den nuværende trigger-summary som autoritativ, fordi den ikke håndterer updates, deletes, backfill eller dubletter korrekt.
