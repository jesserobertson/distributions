from libcpp.vector cimport vector
from cython.operator cimport dereference as deref, preincrement as inc
from distributions.lp.random cimport rng_t, global_rng
from distributions.sparse_counter cimport SparseCounter
from distributions.mixins import ComponentModel, Serializable


ctypedef unsigned Value


cdef extern from "distributions/models/dpd.hpp" namespace "distributions":
    cdef cppclass Model_cc "distributions::DirichletProcessDiscrete":
        float gamma
        float alpha
        float beta0
        vector[float] betas
        #cppclass Value
        cppclass Group:
            SparseCounter counts
        cppclass Sampler:
            vector[float] probs
        cppclass Scorer:
            vector[float] scores
        void group_init (Group &, rng_t &) nogil
        void group_add_value (Group &, Value &, rng_t &) nogil
        void group_remove_value (Group &, Value &, rng_t &) nogil
        void group_merge (Group &, Group &, rng_t &) nogil
        void sampler_init (Sampler &, Group &, rng_t &) nogil
        Value sampler_eval (Sampler &, rng_t &) nogil
        Value sample_value (Group &, rng_t &) nogil
        float score_value (Group &, Value &, rng_t &) nogil
        float score_group (Group &, rng_t &) nogil


cdef class Group:
    cdef Model_cc.Group * ptr
    def __cinit__(self):
        self.ptr = new Model_cc.Group()
    def __dealloc__(self):
        del self.ptr

    def load(self, dict raw):
        cdef SparseCounter * counts = & self.ptr.counts
        counts.clear()
        cdef dict raw_counts = raw['counts']
        cdef str i
        cdef int count
        for i, count in raw_counts.iteritems():
            counts.init_count(int(i), count)

    def dump(self):
        cdef dict counts = {}
        cdef SparseCounter.iterator it = self.ptr.counts.begin()
        cdef SparseCounter.iterator end = self.ptr.counts.end()
        while it != end:
            counts[str(deref(it).first)] = deref(it).second
            inc(it)
        return {'counts': counts}


cdef class Model_cy:
    cdef Model_cc * ptr
    def __cinit__(self):
        self.ptr = new Model_cc()
    def __dealloc__(self):
        del self.ptr

    def load(self, dict raw):
        self.ptr.gamma = raw['gamma']
        self.ptr.alpha = raw['alpha']
        self.ptr.beta0 = raw['beta0']
        self.ptr.betas.clear()
        cdef dict raw_betas = raw['betas']
        self.ptr.betas.resize(len(raw_betas))
        cdef str i
        cdef float beta
        for i, beta in raw_betas.iteritems():
            self.ptr.betas[int(i)] = beta

    def dump(self):
        cdef dict betas = {}
        cdef int i
        for i in xrange(self.ptr.betas.size()):
            betas[str(i)] = self.ptr.betas[i]
        return {
            'gamma': float(self.ptr.gamma),
            'alpha': float(self.ptr.alpha),
            'beta0': float(self.ptr.beta0),
            'betas': betas,
        }

    #-------------------------------------------------------------------------
    # Mutation

    def group_init(self, Group group):
        self.ptr.group_init(group.ptr[0], global_rng)

    def group_add_value(self, Group group, Value value):
        self.ptr.group_add_value(group.ptr[0], value, global_rng)

    def group_remove_value(self, Group group, Value value):
        self.ptr.group_remove_value(group.ptr[0], value, global_rng)

    def group_merge(self, Group destin, Group source):
        self.ptr.group_merge(destin.ptr[0], source.ptr[0], global_rng)

    #-------------------------------------------------------------------------
    # Sampling

    def sample_value(self, Group group):
        cdef Value value = self.ptr.sample_value(group.ptr[0], global_rng)
        return value

    def sample_group(self, int size):
        cdef Group group = Group()
        cdef Model_cc.Sampler sampler
        self.ptr.sampler_init(sampler, group.ptr[0], global_rng)
        cdef list result = []
        cdef int i
        cdef Value value
        for i in xrange(size):
            value = self.ptr.sampler_eval(sampler, global_rng)
            result.append(value)
        return result

    #-------------------------------------------------------------------------
    # Scoring

    def score_value(self, Group group, Value value):
        return self.ptr.score_value(group.ptr[0], value, global_rng)

    def score_group(self, Group group):
        return self.ptr.score_group(group.ptr[0], global_rng)

    #-------------------------------------------------------------------------
    # Examples

    EXAMPLES = [
        {
            'model': {
                'gamma': 0.5,
                'alpha': 0.5,
                'beta0': 0.0,  # must be zero for unit tests
                'betas': {
                    '0': 0.5,
                    '1': 0.5,
                    '2': 0.5,
                },
            },
            'values': [0, 1, 0, 2, 0, 1, 0],
        },
    ]


class DirichletProcessDiscrete(Model_cy, ComponentModel, Serializable):

    #-------------------------------------------------------------------------
    # Datatypes

    Value = int

    Group = Group


Model = DirichletProcessDiscrete