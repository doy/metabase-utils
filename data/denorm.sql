DROP VIEW IF EXISTS spending;
DROP VIEW IF EXISTS future_transactions;
DROP VIEW IF EXISTS denorm_scheduled_transactions;
DROP VIEW IF EXISTS denorm_transactions;

CREATE VIEW denorm_transactions AS
    WITH
    transactions_with_subtransactions AS (
        SELECT
            transactions.id,
            subtransactions.id AS subtransaction_id,
            transactions.date,
            coalesce(subtransactions.amount, transactions.amount) AS amount,
            coalesce(subtransactions.memo, transactions.memo) AS memo,
            transactions.cleared,
            transactions.approved,
            transactions.flag_color,
            transactions.account_id,
            coalesce(subtransactions.payee_id, transactions.payee_id) AS payee_id,
            coalesce(subtransactions.category_id, transactions.category_id) AS category_id,
            coalesce(subtransactions.transfer_account_id, transactions.transfer_account_id) AS transfer_account_id
        FROM
            transactions LEFT JOIN subtransactions ON (
                transactions.id = subtransactions.transaction_id
            )
    )
    SELECT
        transactions_with_subtransactions.id,
        subtransaction_id,
        date,
        amount / 1000.0 as amount,
        memo,
        cleared,
        approved,
        flag_color,
        tins.name as nonprofit_name,
        tins.tin as nonprofit_tin,
        account_id,
        accounts.name AS account,
        payee_id,
        payees.name AS payee,
        category_group_id,
        category_groups.name AS category_group,
        category_id,
        categories.name AS category,
        transactions_with_subtransactions.transfer_account_id,
        transfer_accounts.name AS transfer_account
    FROM
        transactions_with_subtransactions LEFT JOIN accounts ON (
            transactions_with_subtransactions.account_id = accounts.id
        ) LEFT JOIN payees ON (
            transactions_with_subtransactions.payee_id = payees.id
        ) LEFT JOIN categories ON (
            transactions_with_subtransactions.category_id = categories.id
        ) LEFT JOIN category_groups ON (
            categories.category_group_id = category_groups.id
        ) LEFT JOIN accounts transfer_accounts ON (
            transactions_with_subtransactions.transfer_account_id = transfer_accounts.id
        ) LEFT JOIN tins ON (
            tins.tin = iif(
                instr(memo, 'tin:') = 0,
                NULL,
                substr(
                    memo,
                    instr(memo, 'tin:') + 4,
                    iif(
                        instr(substr(memo, instr(memo, 'tin:') + 4), ' ') = 0,
                        length(memo),
                        instr(
                            substr(
                                memo,
                                instr(memo, 'tin:') + 4
                            ),
                            ' '
                        ) - 1
                    )
                )
            )
        );

CREATE VIEW denorm_scheduled_transactions AS
    WITH
    scheduled_transactions_with_subtransactions AS (
        SELECT
            scheduled_transactions.id,
            scheduled_subtransactions.id AS scheduled_subtransaction_id,
            scheduled_transactions.date,
            scheduled_transactions.frequency,
            coalesce(scheduled_subtransactions.amount, scheduled_transactions.amount) AS amount,
            coalesce(scheduled_subtransactions.memo, scheduled_transactions.memo) AS memo,
            scheduled_transactions.flag_color,
            scheduled_transactions.account_id,
            coalesce(scheduled_subtransactions.payee_id, scheduled_transactions.payee_id) AS payee_id,
            coalesce(scheduled_subtransactions.category_id, scheduled_transactions.category_id) AS category_id,
            coalesce(scheduled_subtransactions.transfer_account_id, scheduled_transactions.transfer_account_id) AS transfer_account_id
        FROM
            scheduled_transactions LEFT JOIN scheduled_subtransactions ON (
                scheduled_transactions.id = scheduled_subtransactions.scheduled_transaction_id
            )
    )
    SELECT
        scheduled_transactions_with_subtransactions.id,
        scheduled_subtransaction_id,
        date,
        frequency,
        amount / 1000.0 as amount,
        memo,
        flag_color,
        tins.name as nonprofit_name,
        tins.tin as nonprofit_tin,
        account_id,
        accounts.name AS account,
        payee_id,
        payees.name AS payee,
        category_group_id,
        category_groups.name AS category_group,
        category_id,
        categories.name AS category,
        scheduled_transactions_with_subtransactions.transfer_account_id,
        transfer_accounts.name AS transfer_account
    FROM
        scheduled_transactions_with_subtransactions LEFT JOIN accounts ON (
            scheduled_transactions_with_subtransactions.account_id = accounts.id
        ) LEFT JOIN payees ON (
            scheduled_transactions_with_subtransactions.payee_id = payees.id
        ) LEFT JOIN categories ON (
            scheduled_transactions_with_subtransactions.category_id = categories.id
        ) LEFT JOIN category_groups ON (
            categories.category_group_id = category_groups.id
        ) LEFT JOIN accounts transfer_accounts ON (
            scheduled_transactions_with_subtransactions.transfer_account_id = transfer_accounts.id
        ) LEFT JOIN tins ON (
            tins.tin = iif(
                instr(memo, 'tin:') = 0,
                NULL,
                substr(
                    memo,
                    instr(memo, 'tin:') + 4,
                    iif(
                        instr(substr(memo, instr(memo, 'tin:') + 4), ' ') = 0,
                        length(memo),
                        instr(
                            substr(
                                memo,
                                instr(memo, 'tin:') + 4
                            ),
                            ' '
                        ) - 1
                    )
                )
            )
        );

CREATE VIEW future_transactions AS
    WITH
    daily AS (
        SELECT
            'daily' AS frequency,
            (ints.i - 1) AS days
        FROM
            ints
        WHERE
            ints.i <= 750
    ),
    weekly AS (
        SELECT
            'weekly' AS frequency,
            (ints.i - 1) * 7 AS days
        FROM
            ints
        WHERE
            ints.i <= 120
    ),
    every_other_week AS (
        SELECT
            'everyOtherWeek' AS frequency,
            (ints.i - 1) * 14 AS days
        FROM
            ints
        WHERE
            ints.i <= 60
    ),
    twice_a_month AS (
        SELECT
            'twiceAMonth' AS frequency,
            a.i AS months,
            b.i AS days
        FROM
            ints a CROSS JOIN ints b
        WHERE
            a.i <= 30 and (b.i = 0 or b.i = 15)
    ),
    every_four_weeks AS (
        SELECT
            'every4Weeks' AS frequency,
            (ints.i - 1) * 28 AS days
        FROM
            ints
        WHERE
            ints.i <= 30
    ),
    monthly AS (
        SELECT
            'monthly' AS frequency,
            (ints.i - 1) AS months
        FROM
            ints
        WHERE
            ints.i <= 30
    ),
    every_other_month AS (
        SELECT
            'everyOtherMonth' AS frequency,
            (ints.i - 1) * 2 AS months
        FROM
            ints
        WHERE
            ints.i <= 15
    ),
    every_three_months AS (
        SELECT
            'every3Months' AS frequency,
            (ints.i - 1) * 3 AS months
        FROM
            ints
        WHERE
            ints.i <= 10
    ),
    every_four_months AS (
        SELECT
            'every4Months' AS frequency,
            (ints.i - 1) * 4 AS months
        FROM
            ints
        WHERE
            ints.i <= 10
    ),
    twice_a_year AS (
        SELECT
            'twiceAYear' AS frequency,
            (ints.i - 1) * 6 AS months
        FROM
            ints
        WHERE
            ints.i <= 5
    ),
    yearly AS (
        SELECT
            'yearly' AS frequency,
            (ints.i - 1) * 12 AS months
        FROM
            ints
        WHERE
            ints.i <= 5
    ),
    every_other_year AS (
        SELECT
            'everyOtherYear' AS frequency,
            (ints.i - 1) * 24 AS months
        FROM
            ints
        WHERE
            ints.i <= 5
    ),
    repeated_transactions AS (
        SELECT
            id,
            scheduled_subtransaction_id,
            CASE
            WHEN frequency = 'never' THEN
                date(date)
            WHEN frequency = 'daily' THEN
                date(date, '+' || daily.days || ' days')
            WHEN frequency = 'weekly' THEN
                date(date, '+' || weekly.days || ' days')
            WHEN frequency = 'everyOtherWeek' THEN
                date(date, '+' || every_other_week.days || ' days')
            WHEN frequency = 'twiceAMonth' THEN
                date(date, '+' || twice_a_month.days || ' days', '+' || twice_a_month.months || ' months')
            WHEN frequency = 'every4Weeks' THEN
                date(date, '+' || every_four_weeks.days || ' days')
            WHEN frequency = 'monthly' THEN
                date(date, '+' || monthly.months || ' months')
            WHEN frequency = 'everyOtherMonth' THEN
                date(date, '+' || every_other_month.months || ' months')
            WHEN frequency = 'every3Months' THEN
                date(date, '+' || every_three_months.months || ' months')
            WHEN frequency = 'every4Months' THEN
                date(date, '+' || every_four_months.months || ' months')
            WHEN frequency = 'twiceAYear' THEN
                date(date, '+' || twice_a_year.months || ' months')
            WHEN frequency = 'yearly' THEN
                date(date, '+' || yearly.months || ' months')
            WHEN frequency = 'everyOtherYear' THEN
                date(date, '+' || every_other_year.months || ' months')
            ELSE
                NULL
            END AS date,
            frequency,
            amount,
            memo,
            flag_color,
            nonprofit_name,
            nonprofit_tin,
            account_id,
            account,
            payee_id,
            payee,
            category_group_id,
            category_group,
            category_id,
            category,
            transfer_account_id,
            transfer_account
        FROM
            denorm_scheduled_transactions
                LEFT JOIN daily USING (frequency)
                LEFT JOIN weekly USING (frequency)
                LEFT JOIN every_other_week USING (frequency)
                LEFT JOIN twice_a_month USING (frequency)
                LEFT JOIN every_four_weeks USING (frequency)
                LEFT JOIN monthly USING (frequency)
                LEFT JOIN every_other_month USING (frequency)
                LEFT JOIN every_three_months USING (frequency)
                LEFT JOIN every_four_months USING (frequency)
                LEFT JOIN twice_a_year USING (frequency)
                LEFT JOIN yearly USING (frequency)
                LEFT JOIN every_other_year USING (frequency)
    )
    SELECT
        id,
        scheduled_subtransaction_id,
        date,
        frequency,
        amount,
        memo,
        flag_color,
        nonprofit_name,
        nonprofit_tin,
        account_id,
        account,
        payee_id,
        payee,
        category_group_id,
        category_group,
        category_id,
        category,
        transfer_account_id,
        transfer_account
    FROM
        repeated_transactions
    WHERE
        date <= date('now', '+2 years');

CREATE VIEW spending AS
    SELECT
        denorm_transactions.id,
        subtransaction_id,
        date,
        amount,
        memo,
        cleared,
        approved,
        flag_color,
        account_id,
        account,
        payee_id,
        payee,
        denorm_transactions.category_group_id,
        category_group,
        category_id,
        category
    FROM
        denorm_transactions LEFT JOIN categories ON (
            denorm_transactions.category_id = categories.id
        )
    WHERE
        amount < 0 AND
        NOT categories.hidden AND
        transfer_account_id IS NULL AND
        category != 'Retirement' and
        category != 'Income Tax' and
        category != 'Donations' and
        category != 'Family' and
        category != 'Reimbursables' and
        category != 'Home Equity';
