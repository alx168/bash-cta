# bash-cta
A simple, lightweight CTA tracker written in Bash.

![An example case of using cta-bash](http://nichite.com/img/bash-cta.png)

## Why?
There's no doubt that when you're on the go, using 
a tracker on your mobile device is the fastest way
to find arrival times.

But if you're on your computer and (like me) always
have a terminal window open, you may find it easier
to lookup a stop with a quick command. I find this
most advantageous when you already know what stop
you want to check, like the stop you may take every
day on a commute.

There are some command-line trackers that exist
for Python and Node JS already, but they have more
dependencies (namely, that you have Python or Node
installed). So I made this.

## Installation
First, clone the repo:

```
git clone https://github.com/nichite/bash-cta.git
# OR, if you're using hub...
hub clone nichite/bash-cta
```

Now, enter the repo directory and run the installer script (makes cta.bash
executable and creates a symbolic link for it in an executable directory):
```
sudo bash installer.bash
```

If you want, you can just run those commands yourself:
```
# Make the file executable
sudo chmod +x ./cta.bash

# Create the link
abspath="$(pwd)/cta.bash"
sudo ln -s $abspath /usr/local/bin/cta
```

## Usage
Enter the station you'd like to see arrivals for with
the `-s` flag, and optionally specify a train route
with the `-r` flag.

Example:
```
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

If you leave out the station or route name, you'll enter
a more interactive mode where the program will prompt
you for input or disambiguation as necessary.

Example:
```
cta
Please list a station that you'd like arrival times for:
grand
Multiple stations found with that name. Enter a route to disambiguate (blank to list all):
r

Results for Grand:

Service toward Howard
           To Howard (R)       1 min away    Approaching
           To Howard (R)       5 min away
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
