package engine

import c "../core"

Node_Vtable :: struct {
	init:      proc(self: rawptr),
	ready:     proc(self: rawptr),
	update:    proc(self: rawptr, dt: f32),
	draw:      proc(self: rawptr, cmd_buf: rawptr),
	exit_tree: proc(self: rawptr),
}

Node :: struct {
	// hierarchy
	parent:           ^Node,
	children:         [dynamic]^Node,
	owner:            ^Node,

	// called through
	vtable:           ^Node_Vtable,

	// instance data
	transform:        c.Transform2D,
	global_transform: c.Transform2D,
	z_index:          f32,
	z_as_relative:    bool,
	visible:          bool,
	name:             string,
	process_flags:    Process_Flags,
}

Process_Flags :: bit_set[Process_Flag]
Process_Flag :: enum {
	update,
	draw,
}

node_default_vtable := &Node_Vtable {
	init = proc(self: rawptr) {},
	ready = proc(self: rawptr) {},
	update = proc(self: rawptr, dt: f32) {},
	draw = proc(self: rawptr, cmd_buf: rawptr) {},
	exit_tree = proc(self: rawptr) {},
}

node_new :: proc(name: string) -> ^Node {
	n := new(Node)
	n.vtable = node_default_vtable
	n.name = name
	n.transform = c.transform_default()
	n.global_transform = c.transform_default()
	n.visible = true
	n.process_flags = {.update, .draw}
	return n
}

node_traverse_update :: proc(node: ^Node, dt: f32) {
    if node.parent != nil {
        node.global_transform = c.transform_compose(
            &node.parent.global_transform,
            &node.transform,
        )
    } else {
        node.global_transform = node.transform
    }

    for child in node.children {
        node_traverse_update(child, dt)
    }

    if .update in node.process_flags {
        node.vtable.update(rawptr(node), dt)
    }
}
