ls assets/seed_data/reticle_subtensions/ | head
ls assets/seed_data/components/
ls assets/seed_data/drag_curves/
jq 'type' assets/seed_data/scopes.json assets/seed_data/optics.json \
        assets/seed_data/reticles.json assets/seed_data/reticles_v2.json
jq 'length' assets/seed_data/scopes.json assets/seed_data/optics.json \
          assets/seed_data/reticles.json assets/seed_data/reticles_v2.json 2>&1

moose
big_foot monster
coyote
boar
dear
elk
bear
rabbit
fox
