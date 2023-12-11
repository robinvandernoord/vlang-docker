#!/usr/bin/env -S v run

import os
import net
import net.http
import json
import time
import arrays

const github_releases_url = 'https://api.github.com/repos/vlang/v/releases'

const docker_repo = 'robinvandernoord/vlang'

const docker_releases_url = 'https://hub.docker.com/v2/repositories/${docker_repo}/tags/?page_size=25&page=1&ordering=last_updated'

fn get_arch() string {
	return os.uname().machine
}

fn print_dots(n int, ch chan bool) {
	mut i := 1
	for true {
		i = (i + 1) % (n + 1)
		d := n - 1
		print('.'.repeat(i) + ' '.repeat(d) + '\r')
		os.flush()

		select {
			_ := <-ch {
				// something received from channel, stop!
				return
			}
			500 * time.millisecond {
				// wait for 500ms then loop
			}
		}
	}
}

fn bash(args ...string) !os.Result {
	ch := chan bool{}
	spawn print_dots(10, ch)
	defer {
		// always make print dots stop at return of function
		ch <- true
	}

	result := os.execute(args.join(' '))
	if result.exit_code != 0 {
		return error(result.str())
	}

	return result
}

fn build_tag(version string) string {
	return '${docker_repo}:${version}-${get_arch()}'
}

fn docker_build(version string, latest bool) !bool {
	mut args := ['docker build .']

	args << '-t ${build_tag(version)}'
	args << '--build-arg="V_VERSION=${version}"'

	// if latest
	if latest {
		args << '-t ${build_tag('latest')}'
	}

	bash(...args)!
	return true
}

fn docker_push(version string, latest bool) !bool {
	mut tags := [build_tag(version)]

	if latest {
		tags << build_tag('latest')
	}

	args := ['docker push']
	for tag in tags {
		println('Starting push on ${tag}.')
		bash(...(arrays.append(args, [tag])))!
	}

	return true
}

struct ReleaseInfo {
	name     string
	tag_name string
	// ...
}

fn get_latest_release() string {
	resp := http.get(github_releases_url + '/latest') or { panic(err) }

	data := json.decode(ReleaseInfo, resp.body) or { panic(err) }

	return data.tag_name
}

fn get_latest_releases(amount int) []string {
	resp := http.get('${github_releases_url}?per_page=${amount}') or { panic(err) }

	data := json.decode([]ReleaseInfo, resp.body) or { panic(err) }

	return data.map(it.tag_name)
}

struct DockerRelease {
	name   string
	images []struct {
		architecture string
		variant      string
	}
}

struct DockerInfo {
	count   int
	results []DockerRelease
}

fn check_existing_build(version string) bool {
	resp := http.get(docker_releases_url) or { panic(err) }

	data := json.decode(DockerInfo, resp.body) or { panic(err) }

	return data.results.filter(it.name == version).len > 0
}

fn build_version(version string, is_latest bool) int {
	tag := '${version}-${get_arch()}'

	if check_existing_build(tag) {
		eprintln('${tag} already exists!')
		return 0
	}

	println('Starting build on ${tag}')

	docker_build(version, is_latest) or { panic('Docker build failed! ${err}') }

	println('Build done!')

	docker_push(version, is_latest) or { panic(err) }

	println('All done!')
	return 0
}

fn cleanup() !bool {
	println("Starting clean up...")
	bash('docker image prune -af')! // --all --force
	return true
}

fn main_(args []string) int {
	defer {
		cleanup() or {}
	}

	if args.len == 0 {
		// build latest
		is_latest := true
		latest := get_latest_release()

		return build_version(latest, is_latest)
	}

	if args.len == 1 && args[0].int() > 0 {
		get_latest_releases(args[0].int()).map(build_version(it, false))
		return 0
	}

	for arg in args {
		build_version(arg, false)
		return 0
	}

	// something went wrong, return exit code 1:
	return 1
}

fn main() {
	/**
	* You can run this script in 3 ways:
	* - `./build.vsh` - build latest release
	* - `./build.vsh 0.4.6 0.4.7` - build specific release(s)
	* - `./build.vsh 5` - build the 5 latest releases
	*/

	exit(main_(os.args[1..]))
}
