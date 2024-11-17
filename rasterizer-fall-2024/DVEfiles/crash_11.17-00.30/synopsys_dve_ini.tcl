gui_state_default_create -off -ini

# Globals
gui_set_state_value -category Globals -key recent_databases -value {{gui_open_db -file wave.vpd}}

# Layout

# list_value_column

# Sim

# Assertion

# Stream

# Data

# TBGUI

# Driver

# Class

# Member

# ObjectBrowser

# UVM

# Local

# Backtrace

# FastSearch

# Exclusion

# SaveSession

# FindDialog
gui_create_state_key -category FindDialog -key m_pMatchCase -value_type bool -value false
gui_create_state_key -category FindDialog -key m_pMatchWord -value_type bool -value false
gui_create_state_key -category FindDialog -key m_pUseCombo -value_type string -value {}
gui_create_state_key -category FindDialog -key m_pWrapAround -value_type bool -value true

# Widget_History
gui_create_state_key -category Widget_History -key TopLevel.1|qt_left_dock|DockWnd2|DLPane.1|pages|Data.1|hbox|textfilter -value_type string -value valid


gui_state_default_create -off
