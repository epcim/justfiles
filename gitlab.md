# GLab

Justfile for glab.

Allow batch processing. Mostly for flexible label assigment.

## Info

An atempted tooling to bend gitlab for kanban and project management capabilities.

## Usage


TL;DR;
```
  just -l
  just --choose

  just milestone="NorthStar-2024" assignee=acme-sre labels=Hardening issue-list
  just labels=xc::\* output=tsv issue-list

  # add labels, based on filter
  just milestone="NorthStar-2024" labels="SRE::Deployment" issue-add-label xc::sre-dev

  # OR between labels
  just assignee=acme-sre labels=xc::\*%AnotherOrLabe issue-list


  # exclude "support/technical" issues to get Release label
  DRY=1 just milestone="NorthStar-2024" exclude="support/technical" issue-add-label Release::Sep-10-2024

  # include specific (filter by url)
  DRY=1 just milestone="NorthStar-2024" include="support/technical" issue-list

  # include specific by gitlab group/namespace
  # just group=acme/security issue-list

  # DRY mode
  DRY=1 just assignee=acme-sre issue-add-label 

  # Open in browser
  just milestone="NorthStar-2024" issue-list | xargs open -g # open in browser

  # Format table (more options would be with `columnt -J`) 
  just milestone="NorthStar-2024" output=ext issue-list | awk ' { printf "\n\n" $1 "\n  "; for (i=2; i<=NF; i++)  printf " "$i" " }'
```

### Project management

#### Repeated team shortcuts

Example: assign milestone, status::new, xc::sre to all sre EMEA team members
```
just team-sre-emea-update
```

### List Issues

```
just assignee=acme-sre include="support" issue-list 
just labels=Release::Jul-30-2024,xc::sre issue-list
just assignee=acme-sre labels=xc::\*%OrAnotherLabel%OrAnotherLabel2 issue-list
just milestone="NorthStar-2024" assignee="acme-sre" exclude="support" issue-list 
```

### Update Issue

Add ~status::new label:
```
  just milestone="NorthStar-2024" issue-add-label
```

Add `helpt-me::sre` label:
```
  just milestone="NorthStar-2024" issue-add-label help-me::sre
```

Add note to multiple issues:

```
just milestone="NorthStar-2024" labels=xyz issue-add-note "request something"

just milestone="NorthStar-2024" output=tsv exclude="support" issue-list | awk '!/Release::/{print $1}' |xargs -I% just issue note % -m \'Please update Release label\' 
```
