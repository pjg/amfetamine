module Dada
  class InvalidPath < Exception; end; # Only used for paths not having parent ids
  class ConfigurationInvalid < Exception;end; # -red
  class UnknownRESTMethod < Exception; end; # Only used if rest method is not handled by dada
  class RecordNotFound < Exception; end;
  class InvalidCacheData < Exception; end;
  class MatcherNotImplemented < Exception; end;
end
