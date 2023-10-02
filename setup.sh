git clone https://github.com/lambdaclass/mina_monorepo.git
cd mina_monorepo
git checkout develop
opam install dune -y
eval $(opam env)
opam switch import opam.export -y
cd src/lib/snarkyjs
npm run bindings
npm run build
