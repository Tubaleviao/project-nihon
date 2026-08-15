"use strict";
// ---------------------------------------------------------------------------
// Local Godot generator.
//
// Forked from @newel/generator-godot@0.0.2 with one fix: the upstream emits
// `class_name XData extends Resource` + enums into each `.gd`, but writes the
// entity fields into the `.tres` WITHOUT declaring them as `@export var` in the
// script. Godot drops undeclared properties on load, so every `.tres` field
// (baseHp, weight, bones, sockets, …) came back `null` at runtime.
//
// This copy adds a `@export var <name>: <type>` line per field so the generated
// resources actually carry their data. Everything else (`.tres` rendering,
// GameData.gd autoload) is unchanged.
// ---------------------------------------------------------------------------

const SUPPORTED_IR_VERSION = '3.0.0';

// ---------------------------------------------------------------------------
// Helpers
// ---------------------------------------------------------------------------
function pascalCase(s) {
    return s
        .replace(/([a-z])([A-Z])/g, '$1_$2')
        .split(/[-_\s]+/)
        .map((w) => w.charAt(0).toUpperCase() + w.slice(1).toLowerCase())
        .join('');
}
function screamingSnake(s) {
    return s
        .replace(/([a-z])([A-Z])/g, '$1_$2')
        .replace(/[-\s]+/g, '_')
        .replace(/[^A-Z0-9_]/gi, '')
        .toUpperCase();
}
function toSlug(s) {
    return s
        .replace(/[\s-]+/g, '_')
        .replace(/[^a-z0-9_]/gi, '')
        .toLowerCase();
}
function pluralizeTag(tag) {
    if (tag.endsWith('y') &&
        !tag.endsWith('ey') &&
        !tag.endsWith('ay') &&
        !tag.endsWith('oy') &&
        !tag.endsWith('uy')) {
        return tag.slice(0, -1) + 'ies';
    }
    if (tag.endsWith('s') ||
        tag.endsWith('sh') ||
        tag.endsWith('ch') ||
        tag.endsWith('x') ||
        tag.endsWith('z')) {
        return tag + 'es';
    }
    return tag + 's';
}

// ---------------------------------------------------------------------------
// .tres resource file
// ---------------------------------------------------------------------------
function renderTres(entity, gdScriptPath) {
    const lines = [];
    lines.push(`[gd_resource type="Resource" format=3]`);
    lines.push('');
    lines.push(`[ext_resource type="Script" path="res://${gdScriptPath}" id="1"]`);
    lines.push('');
    lines.push('[resource]');
    lines.push('script = ExtResource("1")');
    for (const field of Object.values(entity.fields)) {
        const value = gdTresValue(field);
        lines.push(`${field.name} = ${value}`);
    }
    if (entity.stateMachine) {
        lines.push(`state_machine_field = "${entity.stateMachine.field}"`);
        lines.push(`initial_state = "${entity.stateMachine.initial}"`);
    }
    if (entity.description) {
        lines.push(`description = ${JSON.stringify(entity.description)}`);
    }
    if (entity.tags.length) {
        const tagStr = entity.tags.map((t) => JSON.stringify(t)).join(', ');
        lines.push(`tags = [${tagStr}]`);
    }
    return lines.join('\n') + '\n';
}

function gdTresValue(field) {
    if (field.defaultValue !== undefined) {
        const v = field.defaultValue;
        if (typeof v === 'boolean')
            return v ? 'true' : 'false';
        if (typeof v === 'number') {
            if (field.type === 'decimal' || field.type === 'number') {
                return Number.isInteger(v) ? v.toFixed(1) : String(v);
            }
            return String(v);
        }
        if (typeof v === 'string' && field.type === 'enum' && field.enumValues) {
            const idx = field.enumValues.indexOf(v);
            if (idx === -1) {
                throw new Error(`@newel/generator-godot: enum field "${field.name}" has defaultValue "${v}" which is not in enumValues [${field.enumValues.join(', ')}]`);
            }
            return String(idx);
        }
        return JSON.stringify(v);
    }
    switch (field.type) {
        case 'integer':
            return '0';
        case 'decimal':
        case 'number':
            return '0.0';
        case 'boolean':
            return 'false';
        case 'enum':
            return '0';
        default:
            return '""';
    }
}

// ---------------------------------------------------------------------------
// GDScript .gd file (enums + @export var declarations)
// ---------------------------------------------------------------------------
function gdEnumConst(val, fieldName) {
    const snake = screamingSnake(val);
    const prefix = fieldName ? screamingSnake(fieldName) + '_' : 'V_';
    if (!snake || /^[0-9]/.test(snake)) {
        return `${prefix}${snake || 'EMPTY'}`;
    }
    return snake;
}

function renderStateMachineEnum(sm) {
    const lines = [];
    lines.push(`enum ${pascalCase(sm.field)} {`);
    const seen = new Set();
    for (const state of Object.values(sm.states)) {
        const constant = gdEnumConst(state.name, sm.field);
        if (seen.has(constant)) {
            throw new Error(`@newel/generator-godot: state machine field "${sm.field}" produces duplicate GDScript constant "${constant}" (from state "${state.name}")`);
        }
        seen.add(constant);
        lines.push(`\t${constant},`);
    }
    lines.push('}');
    return lines.join('\n');
}

// Map a fabric FieldType to a GDScript @export type. `json` fields are typed
// Array or Dictionary based on their default value; enum fields are stored in
// the .tres as their integer index, so they surface as `int`.
function gdType(field) {
    switch (field.type) {
        case 'integer':
            return 'int';
        case 'decimal':
        case 'number':
            return 'float';
        case 'boolean':
            return 'bool';
        case 'enum':
            return 'int';
        case 'json':
            if (Array.isArray(field.defaultValue))
                return 'Array';
            if (field.defaultValue && typeof field.defaultValue === 'object')
                return 'Dictionary';
            return 'Variant';
        case 'string':
        case 'uuid':
        case 'email':
        case 'url':
        case 'timestamp':
        case 'date':
        default:
            return 'String';
    }
}

// GDScript reserved words that cannot be used as `@export var` names. A fabric
// field that collides with one of these must be renamed in the fabric (fail
// loudly rather than emit GDScript that won't parse).
const GDScript_RESERVED = new Set([
    'if', 'elif', 'else', 'for', 'while', 'match', 'break', 'continue', 'pass', 'return',
    'class', 'class_name', 'extends', 'is', 'in', 'as', 'self', 'super', 'signal', 'func',
    'static', 'const', 'enum', 'var', 'breakpoint', 'preload', 'await', 'yield', 'assert',
    'void', 'null', 'true', 'false',
    'int', 'float', 'bool', 'String', 'Array', 'Dictionary', 'Variant', 'Object',
    'Vector2', 'Vector3', 'Vector4', 'Color', 'RID', 'Callable', 'Signal', 'Node',
]);

function renderGd(entity) {
    const smField = entity.stateMachine && entity.stateMachine.field;
    const enumFields = Object.values(entity.fields).filter((f) => f.type === 'enum' && f.enumValues && f.enumValues.length && f.name !== smField);
    const hasSm = entity.stateMachine && Object.keys(entity.stateMachine.states).length > 0;
    const lines = [];
    lines.push(`class_name ${entity.name}Data`);
    lines.push(`extends Resource`);
    lines.push('');
    for (const field of enumFields) {
        lines.push(`enum ${pascalCase(field.name)} {`);
        const seen = new Set();
        for (const val of field.enumValues) {
            const constant = gdEnumConst(val, field.name);
            if (seen.has(constant)) {
                throw new Error(`@newel/generator-godot: enum field "${field.name}" produces duplicate GDScript constant "${constant}" (from value "${val}")`);
            }
            seen.add(constant);
            lines.push(`\t${constant},`);
        }
        lines.push('}');
        lines.push('');
    }
    if (hasSm) {
        lines.push(renderStateMachineEnum(entity.stateMachine));
    }
    // The fix: declare every field so the .tres properties are stored.
    lines.push('');
    for (const field of Object.values(entity.fields)) {
        if (GDScript_RESERVED.has(field.name)) {
            throw new Error(`@newel/generator-godot: field "${field.name}" on entity "${entity.name}" is a GDScript reserved word — rename it in the fabric`);
        }
        lines.push(`@export var ${field.name}: ${gdType(field)}`);
    }
    return lines.join('\n') + '\n';
}

// ---------------------------------------------------------------------------
// GameData.gd autoload singleton
// ---------------------------------------------------------------------------
function renderGameData(schema) {
    const lines = [];
    lines.push(`extends Node`);
    lines.push(`# Add to Project → Autoload as "GameData"`);
    lines.push('');
    const groups = {};
    for (const entity of Object.values(schema.entities)) {
        const tag = toSlug(entity.tags[0] ?? 'other');
        if (!groups[tag])
            groups[tag] = [];
        groups[tag].push(entity.name);
    }
    for (const [tag, names] of Object.entries(groups).sort()) {
        const dir = pluralizeTag(tag);
        const varName = screamingSnake(dir);
        const entries = names
            .sort()
            .map((n) => {
            const slug = toSlug(n);
            return `\t\t${JSON.stringify(n)}: preload("res://godot/${dir}/${slug}.tres")`;
        })
            .join(',\n');
        lines.push(`const ${varName}: Dictionary = {`);
        lines.push(entries);
        lines.push('}');
        lines.push('');
    }
    return lines.join('\n') + '\n';
}

// ---------------------------------------------------------------------------
// Generator
// ---------------------------------------------------------------------------
class GodotGenerator {
    name = 'godot';
    dependsOn = [];
    async generate(schema, _ctx) {
        if (schema.version !== SUPPORTED_IR_VERSION) {
            throw new Error(`@newel/generator-godot requires IR version ${SUPPORTED_IR_VERSION}, got ${schema.version}`);
        }
        const files = [];
        const gdHeader = `# @generated by @newel/generator-godot — do not edit\n`;
        const seenPaths = new Set();
        for (const entity of Object.values(schema.entities)) {
            const tag = entity.tags[0] ?? 'other';
            const slug = toSlug(entity.name);
            const dir = pluralizeTag(toSlug(tag));
            const tresPath = `godot/${dir}/${slug}.tres`;
            const gdPath = `godot/${dir}/${slug}.gd`;
            if (seenPaths.has(tresPath)) {
                throw new Error(`@newel/generator-godot: entities "${entity.name}" and another entity produce the same output path "${tresPath}" — rename one of them`);
            }
            seenPaths.add(tresPath);
            files.push({
                path: gdPath,
                content: renderGd(entity),
                header: gdHeader,
            });
            files.push({
                path: tresPath,
                content: renderTres(entity, gdPath),
                header: '',
            });
        }
        files.push({
            path: `godot/autoload/GameData.gd`,
            content: renderGameData(schema),
            header: gdHeader,
        });
        return { files };
    }
}
exports.GodotGenerator = GodotGenerator;
