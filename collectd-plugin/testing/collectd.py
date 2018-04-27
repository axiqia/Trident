class Values:
  def __init__(self,**kwargs):
    self.host = ''
    self.plugin = ''
    self.plugin_instance = ''
    self.time = 0
    self.type = ''
    self.type_instance = ''
    for key, val in kwargs.iteritems():
      self.__dict__.update({key: val});

  def dispatch(self,**kwargs):
    print 'here type=',self.type,' type_instance=',self.type_instance,' values=',self.values,' timestamp=', self.time
