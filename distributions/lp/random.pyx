from libcpp.vector cimport vector
from libcpp.utility cimport pair
from python cimport PyObject

ctypedef PyObject* O


cdef extern from 'distributions/std_wrapper.hpp' namespace 'std_wrapper':
    cppclass rng_t:
        int sample "operator()" () nogil
    cdef rng_t global_rng


cdef extern from "distributions/random.hpp" namespace "distributions":
    cdef pair[O, O] _sample_pair_from_urn "distributions::sample_pair_from_urn<PyObject *>" (
            rng_t & rng,
            vector[O] & urn) nogil


cpdef sample_pair_from_urn(list urn):
    cdef vector[O] _urn
    for item in urn:
        _urn.push_back(<O> item)
    cdef pair[O, O] result = _sample_pair_from_urn(global_rng, _urn)
    return (<object> result.first, <object> result.second)