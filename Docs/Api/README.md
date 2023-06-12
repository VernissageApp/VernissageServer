# API documentation 

API documentation is created by (Slate)[https://github.com/slatedocs/slate]. 

Pull documentation Docker image from repository:

```
docker pull slatedocs/slate
```

Run Docker image which will serve markdown file as HTML:

```bash
docker run --rm --name slate -p 4567:4567 -v $(pwd):/srv/slate/source slatedocs/slate serve
```

Build documentation:

```bash
docker run --rm --name slate -v $(pwd)/build:/srv/slate/build -v $(pwd):/srv/slate/source slatedocs/slate build
```
