import sys
from shutil import copyfile


class Replace:
    def __init__(self, filename):
        self.filename = filename

    def replace_with_prompt(self):
        print("Format postgresql://USERNAME:PASSWORD@DB_SERVER_URL/DB_NAME")
        sqlalchemy_url = input("Enter your sqlalchemy_url: ")
        if not sqlalchemy_url:
            sqlalchemy_url = 'p://u:p@db/nm'

        print("Format - default_cacheuk_dev")
        site_id = input("Enter your site_id: ")
        if not site_id:
            site_id = 'site_id_ckan_thingy'

        print("Format - http://HOST_URL/ckan")
        site_url = input("Enter your site_url: ")
        if not site_url:
            site_url = 'h://h.com/ckan'

        self.replace_with_args([None, self.filename, sqlalchemy_url, site_url, site_id])

    def replace_with_args(self, args):
        with open(self.filename, 'r') as template:
            with open('{}.tmp'.format(self.filename), 'w') as tmp_file:
                for line in template.readlines():

                    if 'sqlalchemy.url' in line:
                        line = 'sqlalchemy.url = {}'.format(args[2])

                    if 'ckan.site_url' in line:
                        line = 'ckan.site_url = {}'.format(args[3])

                    if 'ckan.site_id' in line:
                        line = 'ckan.site_id = {}'.format(args[4])

                    tmp_file.write(line)

        # copyfile('{}.tmp'.format(self.filename), self.filename)


if __name__ == '__main__':
    args_list = sys.argv
    if len(args_list) < 2:
        filename = 'install_files/production_tpl.ini'
    else:
        filename = args_list[1]

    replace_words = Replace(filename)
    if len(args_list) > 2:
        print(args_list)
        replace_words.replace_with_args(args_list)
    else:
        replace_words.replace_with_prompt()
