#include "native_chunk_builder.h"

#include <godot_cpp/variant/packed_string_array.hpp>

using namespace godot;

void NativeChunkBuilder::_bind_methods() {
	ClassDB::bind_method(D_METHOD("version"), &NativeChunkBuilder::version);
	ClassDB::bind_method(D_METHOD("functions"), &NativeChunkBuilder::functions);
}

int NativeChunkBuilder::version() const {
	return 1;
}

PackedStringArray NativeChunkBuilder::functions() const {
	return PackedStringArray();
}
