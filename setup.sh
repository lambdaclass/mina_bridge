git clone https://github.com/lambdaclass/mina_monorepo.git
cd mina_monorepo
git checkout remove_automation_dir
opam install dune
opam switch import opam.export
cd src/lib/snarkyjs
npm run bindings
npm run build
