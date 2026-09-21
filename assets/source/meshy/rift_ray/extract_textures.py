"""Extract exact embedded image bytes from the untouched Meshy GLB."""
import json
import struct
from pathlib import Path

source = Path(__file__).with_name('ray_a.glb')
data = source.read_bytes()
if data[:4] != b'glTF':
    raise ValueError('Not a binary glTF')
json_len, json_type = struct.unpack_from('<II', data, 12)
if json_type != 0x4E4F534A:
    raise ValueError('Missing JSON chunk')
doc = json.loads(data[20:20+json_len])
bin_header = 20+json_len
bin_len, bin_type = struct.unpack_from('<II', data, bin_header)
if bin_type != 0x004E4942:
    raise ValueError('Missing BIN chunk')
bin_start = bin_header+8
out = source.parent/'ray_a_textures'
out.mkdir(exist_ok=True)
names = {0:'normal.png', 1:'base_color.jpg', 2:'metallic_roughness.jpg'}
for index, image in enumerate(doc['images']):
    view = doc['bufferViews'][image['bufferView']]
    start = bin_start+view.get('byteOffset', 0)
    payload = data[start:start+view['byteLength']]
    if len(payload) != view['byteLength']:
        raise ValueError('Truncated image')
    (out/names[index]).write_bytes(payload)
    print(names[index], len(payload))
