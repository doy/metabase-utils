use std::io::Write;

struct Sheet(Vec<Vec<String>>);

impl Sheet {
    fn new(contents: &str) -> Self {
        let mut rdr = csv::ReaderBuilder::new()
            .has_headers(false)
            .from_reader(contents.as_bytes());
        let sheet = rdr
            .records()
            .map(|record| {
                record.unwrap().iter().map(|s| s.to_string()).collect()
            })
            .collect();
        Self(sheet)
    }

    #[allow(dead_code)]
    fn value_at(&self, coord: &str) -> String {
        let letter = coord.chars().next().unwrap();
        let num: usize = coord[1..].parse().unwrap();
        let row = num - 1;
        let col = ((letter as u32) - ('A' as u32)) as usize;
        let Self(sheet) = self;
        sheet[row][col].clone()
    }

    fn rows(&self) -> impl Iterator<Item = &Vec<String>> + '_ {
        let Self(sheet) = self;
        sheet.iter()
    }
}

fn get(url: &str) -> String {
    let r = reqwest::blocking::Client::builder()
        .user_agent("Mozilla/5.0 (X11; Linux x86_64; rv:145.0) Gecko/20100101 Firefox/145.0")
        .build()
        .unwrap();
    r.get(url).send().unwrap().text().unwrap()
}

fn main() {
    let sheets: Vec<_> = std::env::args()
        .skip(1)
        .map(|u| Sheet::new(&get(&u)))
        .collect();

    let mut file =
        std::fs::File::create("investment_categories.tsv").unwrap();
    for row in sheets[0].rows().skip(1) {
        if row[0].is_empty() {
            break;
        }
        let percentage: f64 = row[1].trim_end_matches('%').parse().unwrap();
        file.write_all(
            [
                row[0].as_ref(),
                format!("{}", (percentage * 100.0) as u32).as_ref(),
            ]
            .join("\t")
            .as_bytes(),
        )
        .unwrap();
        file.write_all(b"\n").unwrap();
    }
    file.sync_all().unwrap();

    let mut names: std::collections::HashMap<String, String> =
        std::collections::HashMap::new();
    let mut prices: std::collections::HashMap<String, String> =
        std::collections::HashMap::new();
    let mut expense_ratios: std::collections::HashMap<String, String> =
        std::collections::HashMap::new();
    let mut file = std::fs::File::create("holdings.tsv").unwrap();
    for row in sheets[1].rows().skip(2) {
        let account: &str = &row[0];
        if account.is_empty() {
            break;
        }

        let symbol = &row[1];
        let out_row = if !symbol.is_empty()
            && symbol.chars().all(|c| c.is_ascii_digit())
        {
            let name = names.entry(symbol.to_string()).or_insert_with(|| {
                let json = get(&format!("https://workplace.vanguard.com/investments/profileServiceProxy?portIds={symbol}"));
                let data: serde_json::Value = serde_json::from_str(&json).unwrap();
                data
                    .get("fundNames")
                    .unwrap()
                    .get("content")
                    .unwrap()
                    .get(0)
                    .unwrap()
                    .get("fundFullName")
                    .unwrap()
                    .as_str()
                    .unwrap()
                    .to_string()
            });
            let price = prices.entry(symbol.to_string()).or_insert_with(|| {
                let json = get(&format!("https://workplace.vanguard.com/investments/valuationPricesServiceProxy?timePeriodCode=D&priceTypeCodes=MKTP,NAV&portIds={symbol}"));
                let data: serde_json::Value = serde_json::from_str(&json).unwrap();
                data
                    .get("fundPrices")
                    .unwrap()
                    .get("content")
                    .unwrap()
                    .get(0)
                    .unwrap()
                    .get("price")
                    .unwrap()
                    .as_f64()
                    .unwrap()
                    .to_string()
            });
            let expense_ratio = expense_ratios.entry(symbol.to_string()).or_insert_with(|| {
                let json = get(&format!("https://workplace.vanguard.com/investments/feesExpenseServiceProxy?portIds={symbol}"));
                let data: serde_json::Value = serde_json::from_str(&json).unwrap();
                data
                    .get("feesExpense")
                    .unwrap()
                    .get("content")
                    .unwrap()
                    .get(0)
                    .unwrap()
                    .get("expense")
                    .unwrap()
                    .get(8)
                    .unwrap()
                    .get("percent")
                    .unwrap()
                    .as_str()
                    .unwrap()
                    .to_string()
            });
            [
                // account
                account,
                // symbol
                symbol,
                // name
                name,
                // category
                &row[3],
                // shares
                &row[7].replace(['$', ','], ""),
                // price
                price,
                // expense ratio
                expense_ratio,
            ]
            .join("\t")
        } else {
            [
                // account
                account,
                // symbol
                if symbol.is_empty() { "\\N" } else { symbol },
                // name
                if row[2].is_empty() { "\\N" } else { &row[2] },
                // category
                &row[3],
                // shares
                &row[7].replace(['$', ','], ""),
                // price
                &row[8].replace(['$', ','], ""),
                // expense ratio
                &row[11],
            ]
            .join("\t")
        };
        file.write_all(out_row.as_bytes()).unwrap();
        file.write_all(b"\n").unwrap();
    }
    file.sync_all().unwrap();
}
