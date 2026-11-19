#!/usr/bin/env bash
# Renders metrics/stats.svg from the GitHub API. GH_TOKEN must be a classic
# token with the repo scope so search counts include private repositories.
set -euo pipefail

user="${STATS_USER:?}"
since="$(date -u -d '1 year ago' +%F)"

count() { gh api "search/issues?q=$1&per_page=1" --jq .total_count; }

contributions="$(gh api graphql -f query="{user(login:\"$user\"){contributionsCollection{contributionCalendar{totalContributions}}}}" \
  --jq .data.user.contributionsCollection.contributionCalendar.totalContributions)"
commits="$(gh api "search/commits?q=author:$user+committer-date:>=$since&per_page=1" --jq .total_count)"
prs="$(count "author:$user+type:pr+created:>=$since")"
merged="$(count "author:$user+type:pr+is:merged+merged:>=$since")"
reviews="$(count "reviewed-by:$user+-author:$user+type:pr+created:>=$since")"

fmt() { # 1541 -> 1,541
  local n="$1" out=""
  while ((${#n} > 3)); do out=",${n: -3}$out"; n="${n:0:${#n}-3}"; done
  printf '%s' "$n$out"
}
row() { # y label value
  printf '  <text x="32" y="%s" class="label">%s</text><text x="300" y="%s" class="value">%s</text>\n' "$1" "$2" "$1" "$(fmt "$3")"
}

mkdir -p metrics
{
  cat <<SVG
<svg xmlns="http://www.w3.org/2000/svg" width="340" height="220" viewBox="0 0 340 220" role="img" aria-label="GitHub stats for $user">
  <style>
    .bg { fill: #ffffff; stroke: #d0d7de; }
    .title { fill: #1f6feb; font: 600 17px -apple-system, 'Segoe UI', Helvetica, Arial, sans-serif; }
    .label { fill: #57606a; font: 400 14px -apple-system, 'Segoe UI', Helvetica, Arial, sans-serif; }
    .value { fill: #1f2328; font: 600 14px -apple-system, 'Segoe UI', Helvetica, Arial, sans-serif; text-anchor: end; font-variant-numeric: tabular-nums; }
    .note { fill: #8c959f; font: 400 11px -apple-system, 'Segoe UI', Helvetica, Arial, sans-serif; }
    @media (prefers-color-scheme: dark) {
      .bg { fill: #0d1117; stroke: #30363d; }
      .title { fill: #58a6ff; }
      .label { fill: #8b949e; }
      .value { fill: #e6edf3; }
      .note { fill: #6e7681; }
    }
  </style>
  <rect class="bg" x="0.5" y="0.5" width="339" height="219" rx="8"/>
  <text x="32" y="40" class="title">GitHub activity, last 12 months</text>
SVG
  row 76 "Contributions" "$contributions"
  row 104 "Commits" "$commits"
  row 132 "Pull requests opened" "$prs"
  row 160 "Pull requests merged" "$merged"
  row 188 "Pull requests reviewed" "$reviews"
  echo '</svg>'
} > metrics/stats.svg
