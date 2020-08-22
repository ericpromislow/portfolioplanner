# portfolio planner
reads csv files from investment statements, emits normalized yaml

uses a `categories.yml` file to categorize each investment in the category of your choice

## Usage

```
ruby bin/investin.rb [options]
     -d, --date STRING                read info for date yyyy-mm-dd
     -i, --input-dir DIR              read csv files from DIR
     -c, --categories FILE            read categories from FILE
         --summary                    emit a summary to stdout
     -s, --spreadsheet FILE           emit the spreadsheet to DIR/PATH
     -f, --force-overwrite            overwrite existing spreadsheet
     -h, --help                       show this info
```

See `sample-categories.yml` for guidance on how to build your own categories file.
The category names aren't set, except for a builtin category called `UNCATEGORIZED` to
group any uncategorized holdings, and you'll also need an entry called `cash` for
the cash holdings.

## Legal stuff

See `LICENSE` for copyright info.

Use this code at your own risk. I make no claims that it will work.
In fact, every time after I've rebalanced my portfolio, in the short term it was the wrong decision. But in the long term things worked out.

## Investing philosophy

### Thought #1

A friend of mine is a teacher with the Ontario public school system, getting ready for retirement.

Ontario teachers have it very lucky.
They make sizable contributions to one of the best-managed pension funds in the world.
No big deal if they retire at the start of a market collapse,
because the fund doesn't need to sell at a loss.
The fund's managers have enough liquidity from the contributions of teachers
starting their career that they can weather the storm and pay out the pensions.
And they can pick up stocks at a bargain, ensuring outsized gains in the future.

This is kind of the opposite of what the individual investor is dealing with,
one who didn't work for a large company for 40 years.
If you retire at the start of a recession, it's your tough luck.
Hence the need to rebalance your portfolio once or twice a year.
In that respect, I'm not so sure RRSPs and IRAs were such a good idea after all,
except for the brokers who were selling retail investment products, and the lucky few
who made good investments.

### Thought #2

You're always going to lose when it comes to investments.

All of these things happen all the time:

* You buy an investment and it drops in price.

* You sell an investment and its price continues to rise.

When you rebalance based on _a priori_ fixed percentages, and don't obsess daily or weekly with your portfolio changes,
you're less susceptible to that thinking.

### Thought #3

I'm still not responsible for any uses of this software. Use at your own risk.
