cd ..
git clone https://github.com/lambdaclass/mina_monorepo.git
cd mina_monorepo
git checkout develop
cd src/lib/snarkyjs
npm run bindings
npm run build
