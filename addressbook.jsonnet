local public = import "./testkeys/public.json";

std.join('\n', [
	'localStorage.clear()',
] + [
	'localStorage["address:%s"] = JSON.stringify(%s)' % [cql.ss58(value), {
		address: value,
		meta: {
			name: key[:std.length(key)-7],
		},
	}],
	for [key, value] in public
	if std.endsWith(key, "-_stash")
] + [
	'localStorage["address:%s"] = JSON.stringify(%s)' % [cql.ss58(value), {
		address: value,
		meta: {
			name: key[:std.length(key)-5],
		},
	}],
	for [key, value] in public
	if std.endsWith(key, "-aura")
])
