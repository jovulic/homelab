# shellcheck shell=bash

# The procedure goes through all repositories. For each repository it iterates
# from oldest to newest image (by create time) and deletes those that are older
# than $image_older_than_time while maintaining a minimum of
# $minimum_number_of_tags.

set -euo pipefail

REGISTRY_URL="@registry_url@"

declare -i minimum_number_of_tags
minimum_number_of_tags="${REGISTRYCLEANUP_MINIMUM_NUMBER_OF_TAGS:-2}"
declare image_older_than_duration_text
image_older_than_duration_text="${REGISTRYCLEANUP_IMAGE_OLDER_THAN_DURATION_TEXT:-7 days ago}"
declare image_older_than_time
image_older_than_time=$(date -Is -d "$image_older_than_duration_text")
declare -i image_older_than_ts
image_older_than_ts=$(date -d "$image_older_than_time" +%s)

echo "Configuration:"
echo "- minimum_number_of_tags=$minimum_number_of_tags"
echo "- image_older_than_time=$image_older_than_time"
echo "- registry_url=$REGISTRY_URL"

function get_repositories() {
	curl -s "$REGISTRY_URL/v2/_catalog" | jq -rc '.repositories[]'
}

function get_tags() {
	local repo=$1
	curl -s "$REGISTRY_URL/v2/$repo/tags/list" | jq -rc '.tags[]'
}

function get_manifest_info() {
	local repo=$1
	local tag=$2
	curl -s -H "Accept: application/vnd.docker.distribution.manifest.v1+json" \
		"$REGISTRY_URL/v2/$repo/manifests/$tag" |
		jq -rc --arg tag "$tag" '
      if .history != null then
          {
              tag: $tag,
              created: (.history[0].v1Compatibility | fromjson | .created)
          }
      else
          empty
      end'
}

function get_digest() {
	local repo=$1
	local tag=$2
	curl -I -s -H 'Accept: application/vnd.docker.distribution.manifest.v2+json' \
		"$REGISTRY_URL/v2/$repo/manifests/$tag" |
		awk 'BEGIN {FS=": "}/^Docker-Content-Digest/{print $2}' |
		tr -d '\r\n'
}

mapfile -t repositories < <(get_repositories)

for repository in "${repositories[@]}"; do
	echo "Processing repository: $repository"

	mapfile -t tags < <(get_tags "$repository")
	num_tags=${#tags[@]}

	if [ "$num_tags" -le "$minimum_number_of_tags" ]; then
		echo "Below or at minimum number of tags ($num_tags <= $minimum_number_of_tags). Skipping."
		continue
	fi

	echo "Fetching manifest info for $num_tags tags..."
	manifests_file=$(mktemp)
	for tag in "${tags[@]}"; do
		get_manifest_info "$repository" "$tag" >>"$manifests_file"
	done

	# Sort tags by creation time
	mapfile -t tags_sorted < <(jq -src 'sort_by(.created) | .[].tag' "$manifests_file")
	rm "$manifests_file"

	deleted_count=0
	for tag in "${tags_sorted[@]}"; do
		# We re-fetch the specific manifest info to be safe and simple.
		manifest_info=$(get_manifest_info "$repository" "$tag")
		if [ -z "$manifest_info" ]; then continue; fi

		create_time=$(echo "$manifest_info" | jq -r '.created')
		create_ts=$(date -d "$create_time" +%s)

		if [ "$create_ts" -lt "$image_older_than_ts" ] &&
			[ $((num_tags - deleted_count)) -gt "$minimum_number_of_tags" ]; then

			digest=$(get_digest "$repository" "$tag")
			if [ -n "$digest" ]; then
				echo "Deleting tag: $tag (Digest: $digest)"
				curl -s -X DELETE "$REGISTRY_URL/v2/$repository/manifests/$digest"
				deleted_count=$((deleted_count + 1))
			else
				echo "Failed to get digest for tag: $tag"
			fi
		fi
	done
	echo "Deleted $deleted_count tags from $repository."
done
