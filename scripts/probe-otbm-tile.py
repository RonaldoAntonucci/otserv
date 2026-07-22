#!/usr/bin/env python3

import argparse
import hashlib
import struct
from pathlib import Path

START = 0xFE
ESCAPE = 0xFD
END = 0xFF
TILE_AREA = 4
TILE = 5
ITEM = 6
HOUSE_TILE = 14
MAP_DATA = 2
ITEM_GROUP_GROUND = 1
ITEM_ATTR_SERVER_ID = 0x10
OTBM_ATTR_TILE_FLAGS = 3
OTBM_ATTR_ITEM = 9
OTBM_TILEFLAG_NOLOGOUT = 1 << 3
ITEM_FLAG_BLOCK_SOLID = 1 << 0


class InvalidOtb(Exception):
    pass


def parse_tree(path: Path, identifier: bytes):
    data = path.read_bytes()
    if len(data) < 8 or data[:4] not in (identifier, bytes(4)):
        raise InvalidOtb(f"{path} has an invalid identifier")

    def parse_node(offset):
        if offset + 1 >= len(data) or data[offset] != START:
            raise InvalidOtb(f"{path} has an invalid node boundary")

        node_type = data[offset + 1]
        offset += 2
        props = bytearray()
        children = []

        while offset < len(data):
            value = data[offset]
            if value == ESCAPE:
                if offset + 1 >= len(data):
                    raise InvalidOtb(f"{path} ends after an escape byte")
                props.append(data[offset + 1])
                offset += 2
            elif value == START:
                child, offset = parse_node(offset)
                children.append(child)
            elif value == END:
                return (node_type, bytes(props), children), offset + 1
            else:
                props.append(value)
                offset += 1

        raise InvalidOtb(f"{path} has an unterminated node")

    root, final_offset = parse_node(4)
    if final_offset != len(data):
        raise InvalidOtb(f"{path} has trailing data")
    return root, hashlib.sha256(data).hexdigest()


def item_types(items_path: Path):
    root, _ = parse_tree(items_path, b"OTBI")
    types = {}

    for group, props, _ in root[2]:
        if len(props) < 4:
            raise InvalidOtb(f"{items_path} has truncated item properties")
        flags = struct.unpack_from("<I", props)[0]
        offset = 4
        server_id = None

        while offset < len(props):
            if offset + 3 > len(props):
                raise InvalidOtb(f"{items_path} has a truncated item attribute")
            attribute = props[offset]
            size = struct.unpack_from("<H", props, offset + 1)[0]
            value_start = offset + 3
            value_end = value_start + size
            if value_end > len(props):
                raise InvalidOtb(f"{items_path} has an invalid item attribute size")
            if attribute == ITEM_ATTR_SERVER_ID and size == 2:
                server_id = struct.unpack_from("<H", props, value_start)[0]
            offset = value_end

        if server_id is not None:
            types[server_id] = (group, flags)

    return types


def inspect_tile(map_path: Path, types, expected_position):
    root, map_sha256 = parse_tree(map_path, b"OTBM")
    matches = []

    for node_type, _, map_children in root[2]:
        if node_type != MAP_DATA:
            continue
        for area_type, area_props, tile_nodes in map_children:
            if area_type != TILE_AREA:
                continue
            if len(area_props) < 5:
                raise InvalidOtb(f"{map_path} has truncated tile-area properties")
            base_x, base_y, z = struct.unpack_from("<HHB", area_props)

            for tile_type, props, child_nodes in tile_nodes:
                if tile_type not in (TILE, HOUSE_TILE):
                    raise InvalidOtb(f"{map_path} has an invalid tile node")
                minimum_size = 6 if tile_type == HOUSE_TILE else 2
                if len(props) < minimum_size:
                    raise InvalidOtb(f"{map_path} has truncated tile properties")
                x = base_x + props[0]
                y = base_y + props[1]
                if (x, y, z) != expected_position:
                    continue

                offset = minimum_size
                tile_flags = 0
                item_ids = []
                while offset < len(props):
                    attribute = props[offset]
                    offset += 1
                    if attribute == OTBM_ATTR_TILE_FLAGS:
                        if offset + 4 > len(props):
                            raise InvalidOtb(f"{map_path} has truncated tile flags")
                        tile_flags = struct.unpack_from("<I", props, offset)[0]
                        offset += 4
                    elif attribute == OTBM_ATTR_ITEM:
                        if offset + 2 > len(props):
                            raise InvalidOtb(f"{map_path} has a truncated inline item")
                        item_ids.append(struct.unpack_from("<H", props, offset)[0])
                        offset += 2
                    else:
                        raise InvalidOtb(f"{map_path} has unknown tile attribute {attribute}")

                for child_type, child_props, _ in child_nodes:
                    if child_type != ITEM or len(child_props) < 2:
                        raise InvalidOtb(f"{map_path} has an invalid item node")
                    item_ids.append(struct.unpack_from("<H", child_props)[0])

                try:
                    state = [(item_id, *types[item_id]) for item_id in item_ids]
                except KeyError as error:
                    raise InvalidOtb(f"item {error.args[0]} is absent from items.otb") from error
                matches.append((tile_flags, state))

    if len(matches) != 1:
        raise InvalidOtb(
            f"expected exactly one tile at {expected_position}, found {len(matches)}"
        )

    tile_flags, state = matches[0]
    has_ground = any(group == ITEM_GROUP_GROUND for _, group, _ in state)
    blocker_count = sum(1 for _, _, flags in state if flags & ITEM_FLAG_BLOCK_SOLID)
    no_logout = bool(tile_flags & OTBM_TILEFLAG_NOLOGOUT)

    print(f"map_sha256={map_sha256}")
    print(f"tile={expected_position[0]},{expected_position[1]},{expected_position[2]}")
    print(f"has_ground={int(has_ground)}")
    print(f"static_blocker_count={blocker_count}")
    print(f"no_logout={int(no_logout)}")
    print("item_ids=" + ",".join(str(item_id) for item_id, _, _ in state))

    return has_ground and blocker_count == 0 and not no_logout


def main():
    parser = argparse.ArgumentParser(description="Inspect one OTBM tile without loading TFS")
    parser.add_argument("map", type=Path)
    parser.add_argument("items", type=Path)
    parser.add_argument("x", type=int)
    parser.add_argument("y", type=int)
    parser.add_argument("z", type=int)
    args = parser.parse_args()

    try:
        valid = inspect_tile(args.map, item_types(args.items), (args.x, args.y, args.z))
    except (InvalidOtb, OSError, struct.error) as error:
        parser.exit(1, f"ERROR: {error}\n")
    if not valid:
        parser.exit(1, "ERROR: tile is not placeable\n")


if __name__ == "__main__":
    main()
