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

fn main() {
    let sheets: Vec<_> = std::env::args()
        .skip(1)
        .map(|u| {
            Sheet::new(&reqwest::blocking::get(&u).unwrap().text().unwrap())
        })
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

    let mut file = std::fs::File::create("holdings.tsv").unwrap();
    for row in sheets[1].rows().skip(2) {
        if row[0].is_empty() {
            break;
        }
        file.write_all(
            [
                row[0].as_ref(),
                if row[1].is_empty() {
                    "\\N"
                } else {
                    row[1].as_ref()
                },
                if row[2].is_empty() {
                    "\\N"
                } else {
                    row[2].as_ref()
                },
                row[3].as_ref(),
                row[7].replace(['$', ','].as_ref(), "").as_ref(),
                row[8].replace(['$', ','].as_ref(), "").as_ref(),
                row[11].as_ref(),
            ]
            .join("\t")
            .as_bytes(),
        )
        .unwrap();
        file.write_all(b"\n").unwrap();
    }
    file.sync_all().unwrap();
}
