DROP TABLE IF EXISTS holdings;
DROP TABLE IF EXISTS investment_categories;

CREATE TABLE investment_categories (
    name text PRIMARY KEY,
    target_allocation integer
);

CREATE TABLE holdings (
    account text,
    symbol text,
    name text,
    category text REFERENCES investment_categories(name),
    shares numeric(10, 3),
    price numeric(10, 2),
    expense_ratio numeric(5, 2),
    PRIMARY KEY (account, symbol, category)
);
