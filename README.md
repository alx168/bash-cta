# bash-cta
A simple, lightweight CTA tracker written in Bash.

![An example case of using cta-bash](http://nichite.com/img/bash-cta.png)

## Why?
There's no doubt that when you're on the go, using 
a tracker on your mobile device is the fastest way
to go.

But if you're on your computer and (like me) always
have a terminal window open, you may find it easier
to lookup a stop with a quick command. I find this
most advantageous when you already know what stop
you want to check, like the stop you may take every
day on a commute.

A more sensible thing to do would have been to make
such a command-line tool in Python or Node, but
wouldn't it be much more unnecessarily difficult
to write the whole thing in Bash? Plus someone already
did those other ones.

## Usage
Enter the station you'd like to see arrivals for with
the `-s` flag, and optionally specify a train route
with the `-r` flag.

Example:
```bash
cta -s Grand -r Blue

# Output:
Results for Grand:

Service toware O'Hare
        To O'Hare (B)     2 min away
        To O'Hare (B)    29 min away      Scheduled
.
.
.
```

Use `cta -l <route>` to list all the stations for a 
given train route.
```
cta -l Blue

# Expected output
Listing all stations on the blue line:

Addison
Austin
.
.
.
```
## How it works
It's stupid simple. I just take your requested station and/or
route, do a quick lookup to convert to machine-friendly station
IDs, then make a curl request to the CTA Train arrivals API
and parse/format/display the response XML.

## Remarks
As of now, this only works for trains (not buses).
