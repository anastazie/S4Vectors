### =========================================================================
### Common operations on List objects
### -------------------------------------------------------------------------
###


### - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - -
### Looping on List objects
###

setMethod("lapply", "List",
          function(X, FUN, ...)
          {
              FUN <- match.fun(FUN)
              ii <- seq_len(length(X))
              names(ii) <- names(X)
              lapply(ii, function(i) FUN(X[[i]], ...))
          })

.sapplyDefault <- base::sapply
environment(.sapplyDefault) <- topenv()
setMethod("sapply", "List", .sapplyDefault)

setGeneric("endoapply", signature = "X",
           function(X, FUN, ...) standardGeneric("endoapply"))

setMethod("endoapply", "list",
          function(X, FUN, ...) lapply(X = X, FUN = match.fun(FUN), ...))

setMethod("endoapply", "data.frame",
          function(X, FUN, ...)
          as.data.frame(lapply(X = X, FUN = match.fun(FUN), ...)))

setMethod("endoapply", "List",
          function(X, FUN, ...) {
              elementTypeX <- elementType(X)
              FUN <- match.fun(FUN)
              for (i in seq_len(length(X))) {
                  elt <- FUN(X[[i]], ...)
                  if (!extends(class(elt), elementTypeX))
                      stop("'FUN' must return elements of class ", elementTypeX)
                  X[[i]] <- elt
              }
              X
          })

setGeneric("mendoapply", signature = "...",
           function(FUN, ..., MoreArgs = NULL) standardGeneric("mendoapply"))

setMethod("mendoapply", "list", function(FUN, ..., MoreArgs = NULL)
          mapply(FUN = FUN, ..., MoreArgs = MoreArgs, SIMPLIFY = FALSE))

setMethod("mendoapply", "data.frame", function(FUN, ..., MoreArgs = NULL)
          as.data.frame(mapply(FUN = match.fun(FUN), ..., MoreArgs = MoreArgs,
                               SIMPLIFY = FALSE)))

setMethod("mendoapply", "List",
          function(FUN, ..., MoreArgs = NULL) {
              X <- list(...)[[1L]]
              elementTypeX <- elementType(X)
              FUN <- match.fun(FUN)
              listData <-
                mapply(FUN = FUN, ..., MoreArgs = MoreArgs, SIMPLIFY = FALSE)
              for (i in seq_len(length(listData))) {
                  if (!extends(class(listData[[i]]), elementTypeX))
                      stop("'FUN' must return elements of class ", elementTypeX)
                  X[[i]] <- listData[[i]]
              }
              X
          })

setGeneric("revElements", signature="x",
    function(x, i) standardGeneric("revElements")
)

### These 2 methods explain the concept of revElements() but they are not
### efficient because they loop over the elements of 'x[i]'.
### There is a fast method for CompressedList objects though.
setMethod("revElements", "list",
    function(x, i)
    {
        x[i] <- lapply(x[i], function(xx)
                    extractROWS(xx, rev(seq_len(NROW(xx)))))
        x
    }
)

setMethod("revElements", "List",
    function(x, i)
    {
        x[i] <- endoapply(x[i], function(xx)
                    extractROWS(xx, rev(seq_len(NROW(xx)))))
        x
    }
)


### - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - -
### Functional programming methods
###

#.ReduceDefault <- base::Reduce
#environment(.ReduceDefault) <- topenv()
.ReduceDefault <- function(f, x, init, right = FALSE, accumulate = FALSE) 
{
    mis <- missing(init)
    len <- length(x)
    if (len == 0L) 
        return(if (mis) NULL else init)
    f <- match.fun(f)
#    if (!is.vector(x) || is.object(x)) 
#        x <- as.list(x)
    ind <- seq_len(len)
    if (mis) {
        if (right) {
            init <- x[[len]]
            ind <- ind[-len]
        }
        else {
            init <- x[[1L]]
            ind <- ind[-1L]
        }
    }
    if (!accumulate) {
        if (right) {
            for (i in rev(ind)) init <- f(x[[i]], init)
        }
        else {
            for (i in ind) init <- f(init, x[[i]])
        }
        init
    }
    else {
        len <- length(ind) + 1L
        out <- vector("list", len)
        if (mis) {
            if (right) {
                out[[len]] <- init
                for (i in rev(ind)) {
                    init <- f(x[[i]], init)
                    out[[i]] <- init
                }
            }
            else {
                out[[1L]] <- init
                for (i in ind) {
                    init <- f(init, x[[i]])
                    out[[i]] <- init
                }
            }
        }
        else {
            if (right) {
                out[[len]] <- init
                for (i in rev(ind)) {
                    init <- f(x[[i]], init)
                    out[[i]] <- init
                }
            }
            else {
                for (i in ind) {
                    out[[i]] <- init
                    init <- f(init, x[[i]])
                }
                out[[len]] <- init
            }
        }
        if (all(sapply(out, length) == 1L)) 
            out <- unlist(out, recursive = FALSE)
        out
    }
}

setMethod("Reduce", "List", .ReduceDefault)
  
.FilterDefault <- base::Filter
environment(.FilterDefault) <- topenv()
setMethod("Filter", "List", .FilterDefault)

.FindDefault <- base::Find
environment(.FindDefault) <- topenv()
setMethod("Find", "List", .FindDefault)

.MapDefault <- base::Map
environment(.MapDefault) <- topenv()
setMethod("Map", "List", .MapDefault)
 
setMethod("Position", "List",
    function(f, x, right = FALSE, nomatch = NA_integer_)
    {
        ## In R-2.12, base::Position() was modified to use seq_along()
        ## internally. The problem is that seq_along() was a primitive
        ## that would let the user define methods for it (otherwise it
        ## would have been worth defining a "seq_along" method for Vector
        ## objects). So we need to redefine seq_along() locally in order
        ## to make base_Position() work.
        seq_along <- function(along.with) seq_len(length(along.with))
        base_Position <- base::Position
        environment(base_Position) <- environment()
        base_Position(f, x, right = right, nomatch = nomatch)
    }
)


### - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - -
### Evaluating.
###

setMethod("within", "List",
          function(data, expr, ...)
          {
            ## cannot use active bindings here, as they break for replacement
            e <- list2env(as.list(data))
            ##e <- as.env(data)
            safeEval(substitute(expr), e, top_prenv(expr))
            l <- mget(ls(e), e)
            l <- l[!sapply(l, is.null)]
            nD <- length(del <- setdiff(names(data), (nl <- names(l))))
            for (nm in nl)
              data[[nm]] <- l[[nm]]
            for (nm in del)
              data[[nm]] <- NULL
            data
          })

setMethod("do.call", c("ANY", "List"),
          function (what, args, quote = FALSE, envir = parent.frame()) {
            args <- as.list(args)
            callGeneric()
          })
