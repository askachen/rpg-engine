extends RefCounted
## Shared numeric contract for authored definitions, transactions and save candidates.
const LIMIT := 9007199254740991.0
const GROUPS := ["stats", "variables"]
const OPERATORS := ["eq", "ne", "lt", "lte", "gt", "gte"]

func finite_number(value) -> bool:
	return (value is int or value is float) and is_finite(float(value)) and abs(float(value)) <= LIMIT

func typed(value, spec: Dictionary) -> bool:
	return finite_number(value) and (spec.get("type") == "number" or (spec.get("type") == "integer" and value == floor(value)))

func valid_value(value, spec: Dictionary) -> bool:
	return typed(value, spec) and value >= spec.get("min", -LIMIT) and value <= spec.get("max", LIMIT)

func definitions_error(content: Dictionary) -> String:
	for group in GROUPS:
		var definitions = content.get(group, {})
		if not definitions is Dictionary: return group + ": expected object"
		for id in definitions:
			var spec = definitions[id]
			if not spec is Dictionary or spec.get("type") not in ["integer", "number"]: return group + "/" + id + ": invalid numeric definition"
			for key in ["min", "max"]:
				if spec.has(key) and not typed(spec[key], spec): return group + "/" + id + "/" + key + ": invalid bound"
			if spec.get("min", -LIMIT) > spec.get("max", LIMIT): return group + "/" + id + ": inverted bounds"
			if not valid_value(spec.get("default", 0), spec): return group + "/" + id + ": invalid default"
	return ""

func normalize(candidate: Dictionary, content: Dictionary) -> bool:
	# Work on detached dictionaries. Never replace malformed stored values with defaults.
	for group in GROUPS:
		var definitions: Dictionary = content.get(group, {})
		if not candidate.get(group, {}) is Dictionary: return false
		var values: Dictionary = candidate.get(group, {}).duplicate(true)
		for id in values:
			if not definitions.has(id) or not valid_value(values[id], definitions[id]): return false
		for id in definitions:
			if not values.has(id): values[id] = content.get("initial", {}).get(group, {}).get(id, definitions[id].get("default", 0))
			if not valid_value(values[id], definitions[id]): return false
			if definitions[id].type == "integer": values[id] = int(values[id])
			else: values[id] = float(values[id])
		if not values.is_empty() or candidate.has(group): candidate[group] = values
	return true

func compare(actual, expected, op: String, spec: Dictionary) -> bool:
	if not valid_value(actual, spec) or not typed(expected, spec): return false
	match op:
		"eq": return actual == expected
		"ne": return actual != expected
		"lt": return actual < expected
		"lte": return actual <= expected
		"gt": return actual > expected
		"gte": return actual >= expected
	return false

func apply(state: Dictionary, content: Dictionary, effect: Dictionary) -> bool:
	var group := "stats" if effect.kind == "stat" else "variables"
	var id: String = effect.get("id", "")
	var spec: Dictionary = content.get(group, {}).get(id, {})
	var value = effect.get("value")
	if spec.is_empty() or not typed(value, spec): return false
	var actual = state.get(group, {}).get(id)
	if not valid_value(actual, spec): return false
	match effect.get("op"):
		"add": value = actual + value
		"set": pass
		_: return false
	if not valid_value(value, spec): return false
	if spec.type == "integer": state[group][id] = int(value)
	else: state[group][id] = float(value)
	return true
