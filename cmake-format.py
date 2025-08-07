with section("format"):
    dangle_parens = True

with section("parse"):
    additional_commands = {
        'target_sources': {
            'pargs': 1,
            'flags': ['INTERFACE'],
            'kwargs': {
                'FILE_SET': 1,
                'BASE_DIRS': '+',
                'FILES': '*'
            }
        }
    }
