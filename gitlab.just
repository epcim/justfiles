
# settings
set export := true
set dotenv-load := true
set positional-arguments

# runtime
fish_bin := `which fish`
bash_bin := `which bash`
temp := `mktemp -d`
glab := "glab"
args := "--per-page 500"
DRY := if env('DRY', "no") =~ "1|y|yes|true" { "echo" } else { "" }
exclude := "NO-FILTER"
include := ""

# variables
group := env('GITLAB_GROUP', "f5/volterra")
labels := ""
assignee := ""
milestone := ""
itteration := ""
#milestone := "XC NorthStar-2024"
epic := ""
output := ""
outfmt := if output == "tsv" { "-O json |jq '.[]|([.web_url, .title[0:50]]+(.labels|sort))|@tsv' -r " } else \
          if output == "csv" { "-O json |jq '.[]|([.web_url, .title[0:50]]+(.labels|sort))|@csv' -r " } else \
          { "-F urls" }
nolabels := ""


# variables glab
GLAB_DISABLE_VERSION_CHECK := "YES"

[private]
@default:
  just -l


#[group('ISSUE')]
# `glab issue` wrapper function
@issue +cmd:
      echo {{glab}} issue {{cmd}}
      $DRY {{glab}} issue {{cmd}}
alias i := issue

# glab issue list wrapper to search by full text query
@search +query:
  just labels="{{labels}}" nolabels="{{nolabels}}"  assignee="{{assignee}}" milestone="{{milestone}}" include="{{include}}" exclude="{{exclude}}" output=tsv args="$args --search '{{query}}'" issue-list 

# glab wrapper
[private]
@_glab *args="":
  {{glab}} {{args}}

# Test function
[private]
test *args=args:
  #just labels="{{labels}}" assignee="{{assignee}}" milestone="{{milestone}}" output="csv" issue | sed 's/,/\t,/' 
  echo "{{glab}} issue list -g "{{group}}" --assignee '{{assignee}}' --milestone="{{milestone}}" {{args}} {{outfmt}}" 
  {{glab}} issue list -g "{{group}}" --assignee '{{assignee}}' --milestone="{{milestone}}" {{args}} {{outfmt}} 

# , separated for AND
# % separated for OR
[private]
@issue-list-by-labels *args=args:
  for i in '{{replace(replace(labels, "%", " "), " ", "' '")}}'; do \
    {{glab}} issue list -g "{{group}}" --label "$i" --not-label "{{nolabels}}" --assignee "{{assignee}}" --milestone="{{milestone}}" {{args}} {{outfmt}} >> {{temp}}/q_labels; \
  done;


#[group('ISSUE')]
# List issues based on two labels with OR condition (as a join of two independent queries)
issue-list *args=args: 
  [[ -z "{{labels}}" ]] || just labels="{{labels}}" nolabels="{{nolabels}}"  temp="{{temp}}" assignee="{{assignee}}" milestone="{{milestone}}" output="{{output}}" issue-list-by-labels {{args}};
  [[ -n "{{labels}}" ]] || $DRY {{glab}} issue list -g "{{group}}" --not-label "{{nolabels}}" --assignee '{{assignee}}' --milestone="{{milestone}}" {{args}} {{outfmt}} >> {{temp}}/q_labels;
  test -e {{temp}}/q_labels && sort -u {{temp}}/q_labels | grep "{{include}}" | grep -Ev "(/work_items/|{{exclude}})" || true

# list all blocker issues for issues having ie: "labels=2025::REAvaliability", arg1 is opt. filter for parrent issue ID
issue-list-blockers parentIssueIDs="null":
  #!/usr/bin/env bash
  {{glab}} api graphql -f query='
    query IssueBlockersByLabel {
            issues(types: [ISSUE], labelName: ["{{ replace_regex(labels,',', '","') }}"], iid: {{replace_regex(parentIssueIDs, "^(?<id>[0-9]*)$", '"$id"') }} ) {
                edges{
                  node{
                    name
                    webUrl
                    blockedByIssues{
                      edges{
                        node{
                          name
                          webUrl
                        }
                      }
                    }
                }
            }
        }
    }' | jq -r '.data.issues.edges[].node| .blockedByIssues.edges[].node.webUrl'
  #}" | jq -r '.data.issues.edges[].node| select(.iid == "{parentIssueUrl}}" )|.blockedByIssues.edges[].node.webUrl'


#[group('ISSUE')]
# Print details about an issue
@issue-show id:
    {{glab}} issue show {{id}}

#[group('ISSUE')]
# Update issue label, only update/create if label does not yet exist
@issue-add-label label="status::new":
    just labels="{{labels}}" nolabels="{{nolabels}}" assignee="{{assignee}}" milestone="{{milestone}}" output="csv" include="{{include}}" exclude="{{exclude}}" issue-list | sed 's/,/\t,/' | grep -v ',"{{replace_regex(label,"::.*", "::")}}' |\
      cut -f1 | xargs -I% $DRY {{glab}} issue update --label '{{label}}' %

#[group('ISSUE')]
# Update label on the issue
@issue-force-label label:
    just labels="{{labels}}" nolabels="{{nolabels}}"  assignee="{{assignee}}" milestone="{{milestone}}" include="{{include}}" exclude="{{exclude}}" issue-list |\
      xargs -I% $DRY {{glab}} issue update --label '{{label}}' %

#[group('ISSUE')]
# Update issue assignee
@issue-add-assignee ass:
    just labels="{{labels}}" nolabels="{{nolabels}}"  assignee="{{assignee}}" milestone="{{milestone}}" include="{{include}}" exclude="{{exclude}}" issue-list |\
      xargs -I% $DRY {{glab}} issue update --assignee '{{ass}}' %

# Update issue assignee (removal)
@issue-remove-assignee ass:
    just labels="{{labels}}" nolabels="{{nolabels}}" assignee="{{assignee}}" milestone="{{milestone}}" include="{{include}}" exclude="{{exclude}}" issue-list |\
      xargs -I% $DRY {{glab}} issue update --assignee '-{{ass}}' %

#[group('ISSUE')]
# Add comment to multiple issues
@issue-add-note +comment:
    just labels="{{labels}}" nolabels="{{nolabels}}" assignee="{{assignee}}" milestone="{{milestone}}" include="{{include}}" exclude="{{exclude}}" issue-list |\
      xargs -I% $DRY {{glab}} issue note % -m "{{comment}}"


# get color from decimal
@get-color decimal: 
  sed "{{decimal}}!d" colors-greenandpurple.txt|awk '{print $1}'

# create labels on group/namespace level
create-label name color="" description="": 
  #!{{bash_bin}}
  export COLOR=`just get-color {{color}}`
  curl --request POST --header "PRIVATE-TOKEN: $GITLAB_TOKEN" --header "Content-Type: application/json" \
    --data '{"name": "{{name}}", "color": "'$COLOR'", "description": "SDC XC App {{name}}"}' \
    https://gitlab.com/api/v4/groups/12645129/labels


@issue-pm-request-update comment labels="Release::Jul-30-2024,blocker/staging-upgrade" exclude="":
  just labels="Release::Jul-30-2024,blocker/staging-upgrade" output=tsv issue-list | grep -v "{{exclude}}" | awk '{print $1}' |xargs -I% just issue note % -m \'ssue, update current status + status:: label and let SRE team to know on \#staging-env the next steps. Thanks.\'

#[group('PM-NOT-TESTED')]
# PM related - reuest to update label
@issue-pm-request-label LABEL:
  just labels="{{labels}}" assignee="{{assignee}}" milestone="{{milestone}}" include="{{include}}" exclude="{{exclude}}" issue-list |\
    awk '!/{{LABEL}}/{print $1}' | $DRY xargs -I% just issue note % -m \'Please update {{LABEL}} label.\' 

# PM related - reuest to update status (if status::new and issue older 3 weeks)
# NOT TESTED, weak impl.
# TBD add AGE parameter
# @issue-pm-request-update MESSAGE:
#   just labels="{{labels}}" assignee="{{assignee}}" milestone="{{milestone}}" include="{{include}}" exclude="{{exclude}}" issue-list |\
#     awk '/status::new/{print $1}' | $DRY xargs -I% just issue note % -m \'Please update progress on the issue by the status:: label. Thanks.\' 


#[group('TEAM')]
# Update labels on SRE EMEA team assigned issues
team-sre-emea-update *ASSIGNEE="j.stefan pcizinsky pawel-powroznik cznewt w.sronek":
  #!/usr/bin/env bash
  set -eo pipefail
  #declare -A MILESTONE=([4568508]="XC NorthStar-2024")
  for i in {{ASSIGNEE}}; do
    just assignee="$i" issue-add-label status::new &&\
    just assignee="$i" issue-add-label priority::normal &&\
    just assignee="$i" exclude="support" issue-add-label xc::sre-dev
    #just assignee="$i" exclude="support" milestone="None"  issue-list | xargs -rn1 just issue update --milestone "${!MILESTONE[@]}"
    # optional
    # just assignee="$i" exclude="support" milestone="${MILESTONE[@]}" output=tsv issue-list | awk '!/Release::/{print $1}' |xargs -I% just issue note % -m \'Please update Release:: label\'
    # just assignee=$i issue-add-label priority::medium
  done;


team-sre-update *ASSIGNEE="fpytloun a.letessier u.hoode s.syedrazack y.sawai s.onoda2 f5cheliu e.kondoh s.rajendran1":
  #!/usr/bin/env bash
  set -eo pipefail
  for i in {{ASSIGNEE}}; do
    just assignee="$i" issue-add-label status::new &&\
    just assignee="$i" issue-add-label priority::normal &&\
    just assignee="$i" exclude="support" issue-add-label xc::sre 
  done;
    # optional
    # just assignee="$i" exclude="support" milestone="${MILESTONE[@]}" output=tsv issue-list | awk '!/Release::/{print $1}' |xargs -I% just issue note % -m \'Please update Release:: label\'
    # just assignee=$i issue-add-label priority::medium

team-sre-dev-update *ASSIGNEE="j.stefan pcizinsky pawel-powroznik cznewt w.sronek d.jung2 odynz b.elles k.rajendran k.sahu l.shen s.desai":
  #!/usr/bin/env bash
  set -eo pipefail
  for i in {{ASSIGNEE}}; do
    just assignee="$i" issue-add-label status::new &&\
    just assignee="$i" issue-add-label priority::normal &&\
    just assignee="$i" exclude="support" issue-add-label xc::sre-dev
  done;


# Relabel, append labels based on other. Re-map area labels.
# OLD="area/eng/sre" NEW="xc::sre", it avoids update new if xc:: exist
relabel OLD="" NEW="":
  #!/usr/bin/env bash
  set -o pipefail
  # defaults
  declare -A MAPPING
  MAPPING["area/AppSecurity"]="xc::appsecurity"
  MAPPING["area/ds"]="xc::data"
  MAPPING["area/eng/be/cdn"]="xc::cdn"
  MAPPING["area/eng/be/control"]="xc::control"
  MAPPING["area/eng/be/data"]="xc::data"
  MAPPING["area/eng/be/dnsGslb"]="xc::dns"
  MAPPING["area/eng/be/orch"]="xc::orchestration"
  MAPPING["area/eng/be/saas"]="xc::eywa"
  MAPPING["area/eng/be/ver"]="xc::dataplane"
  MAPPING["area/eng/big-ip-apmaas"]="xc::bigip"
  MAPPING["area/eng/f5xc-ddos"]="xc::ddos"
  MAPPING["area/eng/fe"]="xc::console"
  MAPPING["area/eng/infrasec"]="xc::platform-sec"
  MAPPING["area/eng/nginx-one"]=":nginx"
  MAPPING["area/eng/shape/data-intelligence"]="xc::di"
  MAPPING["area/eng/sre"]="xc::sre"
  MAPPING["area/eng/via"]="xc::via"
  MAPPING["area/iam"]="xc::platform-sec"
  MAPPING["area/infraeng"]="xc::infraops"
  MAPPING["area/infraops"]="xc::infraops"
  MAPPING["area/lma"]="xc::lma"
  MAPPING["area/netops"]="xc::neteng"
  MAPPING["area/vuln_mgmt"]="xc::secops"
  MAPPING["console/monitoring"]="xc::console"
  #area/eng/shape/risk 
  #area/eng/shape/csd	
  #area/eng/shape/risk	
  #area/eng/shape/bot	
  #
  # remap if param passed
  test -z ${NEW} ||\
    declare -A MAPPING=(["$OLD"]="$NEW")
  # loop
  for i in ${!MAPPING[@]}; do
    # avoiding to update any issues with XC label and if multiple AREA labels are present
    [[ "{{labels}}" == "" ]] && l="$i" || l="$i,{{labels}}"
    labels=
    just labels="$l" exclude="{{exclude}}|${MAPPING[$i]/::*/}::*" output="csv" include="{{include}}" issue-list | grep -vP 'area.*area' |\
      cut -d, -f1 | xargs -rI% $DRY {{glab}} issue update --label "${MAPPING[$i]}" %; true;
    sleep 10
  done;


# TOOLS

# open url
[private]
@open url *args:
  open {{args}} {{url}}

# tail
[private]
tail n="200":
    tail -{{n}}f {{temp}}/cmdlog

# schedules operations formatted like '<cron_expression> <decrypt|encrypt> <target>'
@_schedule operation:
    @just _run_detached "schedule" "{{operation}}"
    @just tail 20

# run detached
@_run_detached command *arguments:
    $DRY nohup {{command}} {{arguments}} #&>| {{temp}}/cmdlog.$RANDOM &



# TO EXPLORE
# | parallel --colsep ' +' -X --tty vi {1}



# API GRAPHQL
# 
# glab api
# query number of tickets per team, status, priority, milestone, release

# glab api issues --paginate
[private]
@query-test:
  #!/usr/bin/env bash
  $DRY {{glab}} api graphql -f query='
    query {
      project(fullPath: "gitlab-org/gitlab-docs") {
        name
        forksCount
        statistics {
          wikiSize
        }
        issuesEnabled
        boards {
          nodes {
            id
            name
          }
        }
      }
    }
  '

[private]
@query-test2:
  #!/usr/bin/env bash
  $DRY {{glab}} api graphql -f query='
    query {
      project(fullPath: "f5/volterra") {
        name
        issuesEnabled
        boards {
          nodes {
            id
            name
          }
        }
      }
    }
  '
  # query($userLogin: String!) {
  # user(login: $userLogin) {
